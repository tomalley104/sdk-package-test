//
//  File.swift
//  
//
//  Created by Eric Eng on 11/5/24.
//

import Foundation
import UIKit
import SwiftUI

#if !SWIFT_PACKAGE
@_implementationOnly import PlayPlayMode
@_implementationOnly import PlayScripting
#else
import PlayPlayMode
import PlayScripting
#endif

open class UIKitBaseViewController<VariableContainerType, ClassType>: UIViewController, PlayAPIVariableWrapper, PrivateVarCallback {
    open private(set) var variables: VariableContainerType?
    open var keyPathToPlayId: [AnyHashable: String] = [:]
    open var playIdToUpdateCall: [String: (Any?) -> Void] = [:]


    internal var _onVarChange: ((PlayVariableEvent) -> Void)?
    private var _varListener: Any?
    private var _globalVarListener: Any?
    private var _playModeController: PlayModeController = .init()
    private var _variableDataToFireOnAppear: [PlayVariableEvent] = []
    private var _didAppear: Bool = false
    weak private var _engine: PlayRuntimeEngine?

    public func initialize(engine: PlayRuntimeEngine, playId: String) {
        self._engine = engine
        do {
            try engine.buildPage(id: playId, fromController: _playModeController)
        } catch {
            print("🚨 [Play] Load Page Error:", error)
        }

        addChild(_playModeController)
        view.addSubview(_playModeController.view)
        _playModeController.didMove(toParent: self)

        // Listeners
        if let scope = _playModeController.initialNVM?.scope {
            _varListener = NotificationCenter.default.addObserver(forName: .playVariableEventNotification, object: scope, queue: .current, using: { [weak self] notif in
                guard
                    let self,
                    let data = notif.userInfo?["data"] as? PlayScripting.VariableEvent
                else { return }
                self._onVarChange?(.init(event: data))
            })
        }

        _globalVarListener = NotificationCenter.default.addObserver(forName: .playVariableEventNotification, object: _playModeController.globalScope, queue: .current, using: { [weak self] notif in
            guard
                let self,
                let data = notif.userInfo?["data"] as? PlayScripting.VariableEvent
            else { return }
            if !self._didAppear {
                _variableDataToFireOnAppear.append(.init(event: data))
            }
        })
    }

    deinit {
        if let _varListener {
            NotificationCenter.default.removeObserver(_varListener)
        }
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _didAppear = true

        _variableDataToFireOnAppear.forEach { data in
            _engine?.setGlobalVariable(id: data.id, value: nil)
            _engine?.setGlobalVariable(id: data.id, value: data.value)
        }

        _variableDataToFireOnAppear.removeAll()
        NotificationCenter.default.removeObserver(_globalVarListener)
    }

    public func setVariable(id: String, value: Any?) {
        _playModeController.initialNVM?.scope.setVariable(id: id, value: value)
    }

    public func getVariable(id: String) -> Any? {
        return _playModeController.initialNVM?.scope.getVariable(id: id)?.value
    }

    public func setVariable<T>(keyPath: KeyPath<VariableContainerType, T>, value: Any?) {
        if let id = keyPathToPlayId[keyPath] {
            _playModeController.initialNVM?.scope.setVariable(id: id, value: value)
        }
    }

    public func getVariablee<T>(keyPath: KeyPath<VariableContainerType, T>) -> Any? {
        if let id = keyPathToPlayId[keyPath] {
            return _playModeController.initialNVM?.scope.getVariable(id: id)
        }
        return nil
    }
}


public protocol SwiftUIBaseViewController: UIViewControllerRepresentable, PlayAPIVariableWrapper { }
extension SwiftUIBaseViewController {
    public static func updateUIViewController(
        _ uiViewController: UIViewControllerType,
        suiController: some SwiftUIBaseViewController,
        addtionalUpdate: (() -> Void)? = nil)
    {
        guard var uiViewController = uiViewController as? (any PlayAPIVariableWrapper & PrivateVarCallback) else {
            addtionalUpdate?()
            return
        }
        uiViewController._onVarChange = nil
        addtionalUpdate?()
        uiViewController._onVarChange = { data in
            suiController.playIdToUpdateCall[data.id]?(data.value)
        }
    }
}
