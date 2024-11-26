//
//  StyleFontDescriptor+Public.swift
//  PlaySDK
//
//  Created by Tom OMalley on 11/19/24.
//

import Foundation
import UIKit
@_implementationOnly import PlaySheets

public struct PlayFontDescriptor {

    // TODO: store or expose properties

    internal let _styleFontDescriptor: StyleFontDescriptor

    public init(fontType: FontType, size: CGFloat? = nil) {
        _styleFontDescriptor = .init(fontType: fontType.asInternalType, size: size)
    }

    // MARK: FontStyle

    public enum FontStyle : String, RawRepresentable, CaseIterable {
        case regular
        case italic

        var asInternalType: StyleFontDescriptor.FontStyle {
            switch self {
            case .italic: return .italic
            case .regular: return .regular
            }
        }
    }

    // MARK: FontType

    public enum FontType {
        case raw(_ postscriptName: String,
                 _ dynamicTypography: DynamicTypography)

        case system(_ fontStyle: FontStyle = .regular,
                    _ weight: UIFont.Weight = .regular,
                    _ width: UIFont.Width = .standard,
                    _ design: UIFontDescriptor.SystemDesign = .default)

        case systemStyle(_ textStyle: UIFont.TextStyle = .body,
                         _ fontStyle: FontStyle = .regular,
                         _ weight: UIFont.Weight? = nil,
                         _ width: UIFont.Width = .standard,
                         _ design: UIFontDescriptor.SystemDesign = .default)

        var asInternalType: StyleFontDescriptor.FontType {
            switch self {
            case .raw(let psn, let dynamicType):
                return .raw(psn, dynamicType.asInternalType)

            case .system(let style, let weight, let width, let design):
                return .system(style.asInternalType, weight, width, design)

            case .systemStyle(let textStyle, let fontStyle, let weight, let width, let design):
                return .systemStyle(textStyle, fontStyle.asInternalType, weight, width, design)

            }
        }
    }

    // MARK: DynamicTypography

    public struct DynamicTypography {

        public static var none: DynamicTypography {
            return .init(style: .auto, boldVariant: .auto(""), isEnabled: false)
        }

        public enum Style : Hashable {
            case auto
            case style(_ textStyle: UIFont.TextStyle)

            public var title: String {
                switch self {
                case .auto:
                    return "(Auto)"
                case .style(let textStyle):
                    return "\(textStyle.title) (\(Int(textStyle.defaultSize))PT)"
                }
            }

            var asInternalType: StyleFontDescriptor.DynamicTypography.Style {
                switch self {
                case .auto:             return .auto
                case .style(let style): return .style(style)
                }
            }
        }

        public enum BoldVariant : Hashable {
            case auto(_ postscriptName: String)
            case variant(_ postscriptName: String)

            public var postscriptName: String? {
                switch self {
                case .auto(let postscriptName):
                    return postscriptName.isEmpty ? nil : postscriptName
                case .variant(let postscriptName):
                    return postscriptName
                }
            }

            public var isAuto: Bool {
                switch self {
                case .auto: return true
                case .variant: return false
                }
            }

            var asInternalType: StyleFontDescriptor.DynamicTypography.BoldVariant {
                switch self {
                case .auto(let psn):    return .auto(psn)
                case .variant(let psn): return .variant(psn)
                }
            }
        }

        public var style: Style
        public var boldVariant: BoldVariant
        public var isEnabled: Bool

        var asInternalType: StyleFontDescriptor.DynamicTypography {
            return .init(
                style: style.asInternalType,
                boldVariant: boldVariant.asInternalType,
                isEnabled: isEnabled
            )
        }

        public init(style: Style,
                    boldVariant: BoldVariant,
                    isEnabled: Bool) {
            self.style = style
            self.boldVariant = boldVariant
            self.isEnabled = isEnabled
        }
    }
}

