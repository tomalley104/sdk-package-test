//
//  PlayVariableEvent+Public.swift
//  PlaySDK
//
//  Created by Tom OMalley on 11/19/24.
//

import Foundation
@_implementationOnly import PlayScripting

// MARK: PlayScripting.Scope.VariableNotification

public extension NSNotification.Name {
    static var playVariableEventNotification: NSNotification.Name { Scope.variableNotification }
}

// MARK: PlayScripting.VariableEvent

public struct PlayVariableEvent {
    public var id: String { event.id }
    public var type: PlayVariableEventType { event.type.asPublicType }
    public var value: Any? { event.value }

    internal let event: VariableEvent
}

internal extension VariableEvent {
    var asPublicType: PlayVariableEvent { .init(event: self) }
}

// MARK: PlayScripting.VariableEvent.EventType

public enum PlayVariableEventType {
    case create
    case update
    case delete

    var asInternalEventType: PlayScripting.VariableEvent.EventType {
        switch self {
        case .create: return .create
        case .update: return .update
        case .delete: return .delete
        }
    }
}

internal extension VariableEvent.EventType {
    var asPublicType: PlayVariableEventType {
        switch self {
        case .create: return .create
        case .update: return .update
        case .delete: return .delete
        @unknown default:
            assertionFailure("\(self) \(#function) unsupported type: \(self)")
            return .create
        }
    }
}
