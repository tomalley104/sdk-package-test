//
//  File.swift
//  
//
//  Created by Joon on 11/14/24.
//

import Foundation
import UIKit

@_implementationOnly import PlayNodes
@_implementationOnly import PlaySheets

public struct PlayTypography {
    public var name: String { _typographyModel.styleFontDescriptor.getRawPostscriptName() ?? "" }
    public var fontSize: CGFloat { _typographyModel.fontSize }
    public var lineHeight: PlayFloat { _typographyModel.lineHeight.asPublicType }
    public var kerning: PlayFloat { _typographyModel.kerning.asPublicType }
    public var textTransform: PlayTextTransformType { _typographyModel.textTransform.asPublicType }

    internal var _typographyModel: TypographyModel

    public init(bundle: Bundle, 
                fontDescriptor: PlayFontDescriptor,
                lineHeight: PlayFloat,
                kerning: PlayFloat,
                textTransform: PlayTextTransformType) {
        _typographyModel = .init(
            styleFontDescriptor: fontDescriptor._styleFontDescriptor,
            lineHeight: lineHeight.asStyleFloat,
            kerning: kerning.asStyleFloat,
            textTransform: textTransform.asTextTransformType
        )
        PlayRuntimeEngine.registerAllFonts(bundle: bundle)
    }

    public func attributedString(_ text: String) -> AttributedString {
        return _typographyModel.attributedString(text)
    }

    public func nsAttributedString(_ text: String) -> NSAttributedString {
        return _typographyModel.nsAttributedString(text)
    }
}
