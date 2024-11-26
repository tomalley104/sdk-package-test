//
//  File.swift
//  
//
//  Created by Eric Eng on 11/3/24.
//

import Foundation
import UIKit
import SwiftUI
import Combine

#if !SWIFT_PACKAGE
@_implementationOnly import PlayNodes
@_implementationOnly import PlayScripting
#else
import PlayNodes
import PlayScripting
#endif

open class UIKitBaseView<VariableContainerType, ClassType>: UIView, PlayAPIVariableWrapper, PrivateVarCallback {
    // MARK: Overrides
    public override var translatesAutoresizingMaskIntoConstraints: Bool {
        didSet { _updateFrameSize() }
    }

    open private(set) var variables: VariableContainerType?
    open var keyPathToPlayId: [AnyHashable: String] = [:]
    open var playIdToUpdateCall: [String: (Any?) -> Void] = [:]

    public var onResize: ((CGSize) -> Void)?
    internal var _nvmId: ObjectIdentifier?

    private var _widthConstraint: NSLayoutConstraint?
    private var _heightConstraint: NSLayoutConstraint?
    private var _topConstraint: NSLayoutConstraint?
    private var _leftConstraint: NSLayoutConstraint?
    private var _lastUsedSize: CGSize = .zero
    private var _lastOnResize: CGSize = .zero

    internal var _onVarChange: ((PlayVariableEvent) -> Void)?
    private var _varListener: Any?
    private var _disposals: Set<AnyCancellable> = []
    private var _nodeView: ContainerNodeView = .init()
    private var viewModel: NodeViewModel? { _nodeView.viewModel }
    private var styleModel: StyleViewModel { _nodeView.styleModel }

    public func initialize(engine: PlayRuntimeEngine, playId: String) {
        do {
            _nvmId = try engine.buildNode(id: playId, fromView: _nodeView)
        } catch {
            print("🚨 [Play] Load Component Error:", error)
        }

        self.addSubview(_nodeView)

        // Do this so we can control the sizing and position ourselves, but still maintain the style model frame info
//        _nodeView.translatesAutoresizingMaskIntoConstraints = false
//        _nodeView.fillSuperview()
//        _nodeView.topAnchor.constraint(equalTo: topAnchor).isActive = true
//        _nodeView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
//        _nodeView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 1).isActive = true
//        _nodeView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 1).isActive = true
//        _nodeView.style.opacity = 0.5

        if let viewModel {
            // Setting runtime specific
            let ownerMainModel = viewModel.model.mainModel ?? viewModel.model
            viewModel.playmodeOwnerMainComponentInstancess = ownerMainModel.componentInstanceModels
            viewModel.playmodeOwnerMainInteractions = ownerMainModel.instanceInteractions
            viewModel.playmodeOwnerMainInteractionEnabled = ownerMainModel.inheritedInteractionEnabled
        }

        // Listeners
        if let viewModel = self.viewModel {
            _varListener = NotificationCenter.default.addObserver(
                forName: .playVariableEventNotification,
                object: viewModel.scope,
                queue: .current,
                using: { [weak self] notif in
                    guard
                        let self,
                        let data = notif.userInfo?["data"] as? PlayScripting.VariableEvent
                    else { return }
                    self._onVarChange?(data.asPublicType)
                }
            )
            
            viewModel.$renderEventsPublisher.sink { [weak self] event in
                guard let self,
                      case .layout = event
//                      _lastOnResize != self._nodeView.styleModel.boxModel.frame.size
                else { return }
                self._updateFrameSize()
            }.store(in: &_disposals)
        }

//        _nodeView.publisher(for: \.frame).dropFirst().sink { [weak self] val in
//            self?._updateFrameSize()
//        }.store(in: &_disposals)
//
//        _nodeView.publisher(for: \.bounds).dropFirst().sink { [weak self] val in
//            self?._updateFrameSize()
//        }.store(in: &_disposals)
    }

    deinit {
        if let _varListener {
            NotificationCenter.default.removeObserver(_varListener)
        }
        if let _nvmId {
            PlayRuntimeEngine._nvmStrongRefs.removeValue(forKey: _nvmId)
        }
    }

    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return _nodeView.hitTest(point, with: event)
    }
//    override public func updateFrameSize(layoutEffects: Bool = false) {
//        defer {
//            if let onResize, _lastOnResize != bounds.size {
//                _lastOnResize = bounds.size
//                onResize(_lastOnResize)
//            }
//        }
//        guard !_updateIfUsingContraints(layoutEffects: layoutEffects) else { return }
//        super.updateFrameSize(layoutEffects: layoutEffects)
//    }

    private func _updateFrameSize() {
        if !_updateIfUsingContraints(layoutEffects: false) {
            frame.size = _nodeView.styleModel.boxModel.frameWithOffsets.size
            _nodeView.backgroundColor = .orange
            print("$$$$ keys", _nodeView.layer.animationKeys())
//            frame.origin.y = -_nodeView.styleModel.boxModel.frameWithOffsets.minY
//            frame.origin.x = -_nodeView.styleModel.boxModel.frameWithOffsets.minX
        }
        if let onResize, _lastOnResize != _nodeView.bounds.size {
            _lastOnResize = _nodeView.bounds.size
            onResize(_lastOnResize)
        }
    }

    public func setVariable(id: String, value: Any?) {
        self.viewModel?.scope.setVariable(id: id, value: value)
    }

    public func getVariable(id: String) -> Any? {
        return self.viewModel?.scope.getVariable(id: id)?.value
    }

    public func setVariable<T>(keyPath: KeyPath<VariableContainerType, T>, value: Any?) {
        if let id = keyPathToPlayId[keyPath] {
            self.viewModel?.scope.setVariable(id: id, value: value)
        }
    }

    public func getVariablee<T>(keyPath: KeyPath<VariableContainerType, T>) -> Any? {
        if let id = keyPathToPlayId[keyPath] {
            return self.viewModel?.scope.getVariable(id: id)
        }
        return nil
    }

    private func _updateIfUsingContraints(layoutEffects: Bool = false) -> Bool {
        guard !self.translatesAutoresizingMaskIntoConstraints else { return false }
        let sizeToUse = styleModel.boxModel.frame.size
        guard sizeToUse != _lastUsedSize else { return true }
        _widthConstraint?.isActive = false
        _heightConstraint?.isActive = false
        _topConstraint?.isActive = false
        _leftConstraint?.isActive = false
        _widthConstraint = self.widthAnchor.constraint(equalToConstant: sizeToUse.width)
        _heightConstraint =  self.heightAnchor.constraint(equalToConstant: sizeToUse.height)
        if let parent = superview {
            _topConstraint =  self.topAnchor.constraint(equalTo: parent.topAnchor, constant: styleModel.boxModel.frameWithOffsets.minY)
            _leftConstraint =  self.leftAnchor.constraint(equalTo: parent.leftAnchor, constant: styleModel.boxModel.frameWithOffsets.minX)
            _topConstraint?.isActive = true
            _leftConstraint?.isActive = true
        }
        _widthConstraint?.isActive = true
        _heightConstraint?.isActive = true
        _lastUsedSize = sizeToUse

                layoutIfNeeded()
//        super.updateFrameSize(layoutEffects: layoutEffects, force: true)

//        if UIView.inheritedAnimationDuration > 0 {
//            superview?.layoutIfNeeded()
//        }

        return true
    }
}


public protocol SwiftUIBaseView: UIViewRepresentable, PlayAPIVariableWrapper { }

extension SwiftUIBaseView {
    public static func updateUIView(_ uiView: UIViewType, suiView: some SwiftUIBaseView,  addtionalUpdate: (() -> Void)? = nil) {

        guard var uiView = uiView as? (any PlayAPIVariableWrapper & PrivateVarCallback) else {
            addtionalUpdate?()
            return
        }
        uiView._onVarChange = nil
        addtionalUpdate?()
        uiView._onVarChange = { data in
            suiView.playIdToUpdateCall[data.id]?(data.value)
        }
    }
}
