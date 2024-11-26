//
//  File.swift
//  
//
//  Created by Eric Eng on 10/30/24.
//

import Foundation
import UIKit

#if !SWIFT_PACKAGE
@_implementationOnly import PlayNodes
@_implementationOnly import PlayPlayMode
@_implementationOnly import PlayScripting
#else
import PlayNodes
import PlayPlayMode
import PlayScripting
#endif

/**
 *  NOTES:
 *  - Always a single PlayModeController since this will compile to one real app
 *  -
 */

public class PlayRuntimeEngine {
    static var _nvmStrongRefs: [ObjectIdentifier: NodeViewModel] = [:]

    var rootPlaymodeController: PlayModeController = PlayModeController(mode: .play)

    var project: ProjectModel
    var _onVarChange: ((PlayVariableEvent) -> Void)?
    
    private var _rootPlaymodePageController: PlayModePageController
    private var _ownerNVM: NodeViewModel
    private var _varListener: Any?
//    private var _nvmStrongRefs: [ObjectIdentifier: NodeViewModel] = [:]

    init(project: ProjectModel) throws {
        // Add a page just for runtime
        let rootPageNode = NodeModel(type: .page)
        project.addNode(rootPageNode)

        // Load runtime page into root play mode
        rootPlaymodeController.load(project: project, ownerModel: rootPageNode)

        if let vc = rootPlaymodeController.rootPageController {
            _rootPlaymodePageController = vc
            _ownerNVM = vc.ownerNVM
            _ = _ownerNVM.scope.parent(_rootPlaymodePageController.scriptingScope)
        } else {
            throw PlayRuntimeEngine.BuildErrors.couldNotCreateView
        }
        self.project = project
        
        // Global Variable listeners
        _varListener = NotificationCenter.default.addObserver(
            forName: .playVariableEventNotification,
            object: rootPlaymodeController.globalScope,
            queue: .current,
            using: { [weak self] notif in
                guard
                    let self,
                    let data = notif.userInfo?["data"] as? PlayScripting.VariableEvent
                else { return }
                self._onVarChange?(data.asPublicType)
            }
        )
    }

    deinit {
        if let _varListener {
            NotificationCenter.default.removeObserver(_varListener)
        }
    }
    
    public func setGlobalVariable(id: String, value: Any?) {
        rootPlaymodeController.globalScope.setVariable(id: id, value: value)
    }
    
    @discardableResult 
    public func onGlobalVariableChange(_ callback: ((PlayVariableEvent) -> Void)?) -> Self {
        _onVarChange = callback
        return self
    }
    
    /// Given the model it will build the view to be used at runtime
    func buildNode(id: String, fromView: AnyNodeViewType) throws -> ObjectIdentifier {
        guard let node = project.nodes[id] else { throw BuildErrors.notFound }
        guard node.isMainComponent else { throw BuildErrors.invalidType }

        // Create a new model and set node as main model
//        let instance = NodeModel(type: .container)
//            .setMain(node)
//            .setReferenceType(.direct)
//        project.addNode(instance)

        // Create NVMs
         let nvm: NodeViewModel = try NodeViewUtils.createNodeViewModels(
            project: project,
            model: node,
            doCreateViews: true,
            overrideFirstNVMView: fromView,
            mode: .play,
            applyState: true,
            customCreateNVM: { nvm in
                // All custom NVM's that have playmode specific logic
                switch nvm.type {
                case .pageLoader:
                    let newPlayModeController: PlayModeController = .init(
                        rootPlayController: self.rootPlaymodeController
                    )
                    newPlayModeController.mode = .play
                    newPlayModeController.isPageLoaderNVM = true
                    newPlayModeController.load(project: self.project)
                    return PlayModePageLoaderNVM(model: nvm, project: self.project, playmodeController: newPlayModeController)

                default:
                    return nil
                }
            }
        )

//        setupScope(nvm: nvm)
        setUpNode(nvm)
        Self._nvmStrongRefs[nvm.objectId] = nvm

        return nvm.objectId

//        throw BuildErrors.couldNotCreateView
    }

    private func setUpNode(_ nvm: NodeViewModel) {
        // Need to add on top (not as a style subview) to prevent modal detent bugs
        nvm.styleModel.needsLayout = true

        // Setup scope variables
        setupScope(nvm: nvm)

        // Interactions
        let interactionManager = _rootPlaymodePageController.interactionManager
        interactionManager.addInteractions(toNVM: nvm)

        NodeViewUtils.loopThroughSubComponentTree(startComponent: nvm) { [weak self] curNVM in
            guard let self = self else { return }
            // For lifecycle methods lets fire the loads and appears
            if let nodeView = curNVM.view as? StyleView {
                nodeView.triggerEvent(StyleView.Events.didLoad, data: .init(), bubbleUp: false)
                if nodeView.superview != nil {
                    nodeView.triggerEvent(StyleView.Events.didAppear, data: .init(), bubbleUp: false)
                }
            }

            if let imageNVM = curNVM as? ImageNodeViewModel {
                imageNVM.unsplashLoaderDelegate = _rootPlaymodePageController
            }
        }
    }

    private func setupScope(nvm: NodeViewModel) {
        _ = nvm.scope.parent(_ownerNVM.scope)

        let nvmToSetup = nvm
        let varCollection = (nvmToSetup.model.mainModel ?? nvmToSetup.model).variables

        varCollection.children.forEach { curVar in
            // Only set variable with default values if it hasnt been set yet. It could be set already if the overrides have already been applied.
            guard !nvmToSetup.scope.variableExists(id: curVar.id) else { return }
            nvmToSetup.scope.setVariable(id: curVar.id, value: curVar.value?.evaluate())
        }

        // Setup scope for descendant component nodes
        nvmToSetup.components.forEach { _, ref in
            guard let nvm = ref.value else { return }
            setupScope(nvm: nvm)
        }
    }

    func buildPage(id: String, fromController: PlayModeController) throws {
        guard let node = project.nodes[id] else { throw BuildErrors.notFound }
        guard node.type == .page else { throw BuildErrors.invalidType }
        fromController.setRootPlayController(self.rootPlaymodeController)
        fromController.load(project: self.project, ownerModel: node, nodeId: id)
    }
}

class TEMPPP: ContainerNodeView {
    
    required init(frame: CGRect) {
        super.init(frame: frame)
        do {
            _ = try PlayRuntimeEngine(project: .init()).buildNode(id: "hi", fromView: self)
        } catch {
            print("\(type(of: self)) init PlayRuntimeEngine failed: \(error)")
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
