//
//  File.swift
//  
//
//  Created by Joon on 11/12/24.
//

import Foundation

public class GlobalObject<VariableContainerType>: PlayAPIVariableWrapper {
    public typealias VariableContainerType = VariableContainerType
    public typealias ClassType = GlobalObject
    
    public var variables: VariableContainerType?
    
    public var keyPathToPlayId: [AnyHashable : String] = [:]
    
    public var playIdToUpdateCall: [String : (Any?) -> Void] = [:]
    weak var _engine: PlayRuntimeEngine?
    
    public init(_ engine: PlayRuntimeEngine?) {
        _engine = engine
        engine?.onGlobalVariableChange { [weak self] data in
            guard let self else { return }
            self.playIdToUpdateCall[data.id]?(data.value)
        }
    }
    
    @discardableResult public func setKeyPathToPlayId(_ newMap: [AnyHashable : String]) -> Self {
        keyPathToPlayId = newMap
        return self
    }
    
    public func setVariable(id: String, val: Any?) {
        _engine?.setGlobalVariable(id: id, value: val)
    }
}
