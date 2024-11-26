//
//  TextTransformType+SDKShim.swift
//  PlaySDK
//
//  Created by Tom OMalley on 11/19/24.
//

import Foundation
@_implementationOnly import PlayNodes

// MARK: PlayNodes.TextTransformType

public enum PlayTextTransformType: String, Hashable {
    case uppercase, lowercase, capitalize, none

    internal var asTextTransformType: TextTransformType {
        switch self {
        case .uppercase:    return .uppercase
        case .lowercase:    return .lowercase
        case .capitalize:   return .capitalize
        case .none:         return .none
        }
    }

    public func getTransformedString(_ string: String) -> String {
        return asTextTransformType.getTransformedString(string)
    }
}

extension TextTransformType {
    internal var asPublicType: PlayTextTransformType {
        switch self {
        case .uppercase:    return .uppercase
        case .lowercase:    return .lowercase
        case .capitalize:   return .capitalize
        case .none:         return .none
        @unknown default:
            customAssert(self, #function, "unsupported type: \(self)")
            return .none
        }
    }
}
