//
//  StyleFloat+SDKShim.swift
//  PlaySDK
//
//  Created by Tom OMalley on 11/19/24.
//

import Foundation
import UIKit

@_implementationOnly import PlaySheets

// MARK: PlaySheets.StyleFloat

public enum PlayFloat {
    case auto
    case value(CGFloat)
    case percent(CGFloat)

    var asStyleFloat: StyleFloat {
        switch self {
        case .auto:                     return .auto
        case .value(let value):         return .init(value)
        case .percent(let value):       return .init(value, isPercent: true)
        }
    }
}

extension StyleFloat {
    var asPublicType: PlayFloat {
        if isAuto {
            return .auto
        } else if isPercent {
            return .percent(value)
        } else {
            return .value(value)
        }
    }
}
