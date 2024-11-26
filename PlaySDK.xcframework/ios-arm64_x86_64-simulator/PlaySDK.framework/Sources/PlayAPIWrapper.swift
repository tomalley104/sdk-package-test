//
//  File.swift
//  
//
//  Created by Eric Eng on 11/8/24.
//

import Foundation
import UIKit

#if !SWIFT_PACKAGE
@_implementationOnly import PlayScripting
#else
import PlayScripting
#endif

public protocol PlayAPIVariableWrapper {
    associatedtype VariableContainerType
    associatedtype ClassType: PlayAPIVariableWrapper

    var variables: VariableContainerType? { get }

    var keyPathToPlayId: [AnyHashable: String] { get }
    var playIdToUpdateCall: [String: (Any?) -> Void] { get set }

    @discardableResult func onVariableChange<VarType>(variable: KeyPath<VariableContainerType, VarType>, _ callback: @escaping ((VarType) -> Void)) -> ClassType
}

protocol PrivateVarCallback {
    var _onVarChange: ((PlayVariableEvent) -> Void)? { get set }
}

extension PlayAPIVariableWrapper {

    /// Performs the block of code when the variable changes.
    /// - Parameter variable: KeyPath of the variable (ex: \\.myVariable)
    /// - Parameter callback: Code to be executed when the variable value changes
    ///
    @discardableResult public func onVariableChange<ValueType>(variable: KeyPath<VariableContainerType, ValueType>, _ callback: @escaping ((_ val: ValueType) -> Void)) -> Self {
        guard let str = keyPathToPlayId[variable] else { return self }
        var mutself = self
        mutself.playIdToUpdateCall[str] = { val in
            switch ValueType.self {
            case is Bool.Type, is Optional<Bool>.Type:
                if let val = val as? ValueType {
                    callback(val)
                    break
                }
                if let val = (val as? BoolCoercible)?.asBool() as? ValueType {
                    callback(val)
                }
            case is String.Type, is Optional<String>.Type:
                if let val = val as? ValueType {
                    callback(val)
                    break
                }
                if let val = (val as? StringCoercible)?.asString() as? ValueType {
                    callback(val)
                }
            case is CGFloat.Type, is Optional<CGFloat>.Type:
                if let val = val as? ValueType {
                    callback(val)
                    break
                }
                if let val = (val as? NumberCoercible)?.asNumber() as? ValueType {
                    callback(val)
                }
            default:
                if let val = val as? ValueType {
                    callback(val)
                }
            }
        }
        return mutself
    }
}
