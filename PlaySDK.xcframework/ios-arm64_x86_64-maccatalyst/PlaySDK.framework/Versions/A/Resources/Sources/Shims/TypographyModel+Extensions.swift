//
//  TypographyModel+SDKShim.swift
//  PlaySDK
//
//  Created by Tom OMalley on 11/19/24.
//

import Foundation
import UIKit

@_implementationOnly import PlayNodes

// MARK: TypographyModel conveniences
// FIXME: absorb into PlayNodes

extension TypographyModel {
    private(set) static var fontNameToUrl: [String: String] = [:]

    @discardableResult func registerFontUrl(url: String) -> Self {
        guard let postscript = self.styleFontDescriptor.getRawPostscriptName() else { return self }
        Self.fontNameToUrl[postscript] = url
        return self
    }

    convenience init(bundle: Bundle, styleFontDescriptor: StyleFontDescriptor, lineHeight: StyleFloat, kerning: StyleFloat, textTransform: TextTransformType) {
        self.init(styleFontDescriptor: styleFontDescriptor, lineHeight: lineHeight, kerning: kerning, textTransform: textTransform)
        PlayRuntimeEngine.registerAllFonts(bundle: bundle)
    }
}


extension TypographyModel {
    func nsAttributedString(_ text: String) -> NSAttributedString {
        return generateAttributedText(text: text)
    }

    func attributedString(_ text: String) -> AttributedString {
        return .init(generateAttributedText(text: text))
    }
}

extension TypographyModel {

    struct FontConfig {
        let font: UIFont
        let fontType: StyleFontDescriptor.FontType
        let dynamicTypeTextStyle: UIFont.TextStyle?
    }

    private func generateAttributedText(text: String) -> NSAttributedString {
        guard !text.isEmpty else { return .init(string: "") }
        let layoutInfo = self
        let transformType: TextTransformType = layoutInfo.textTransform
        let kern: StyleFloat = layoutInfo.kerning
        let lineHeight: StyleFloat = layoutInfo.lineHeight
//        let decorations: [TextDecoration]? = layoutInfo.textDecoration

        let transformedText: String = transformType.getTransformedString(text)
        var attrString = NSMutableAttributedString(string: transformedText)
        let fontConfig: FontConfig = getFontConfig(layoutInfo: layoutInfo, lastRegisteredFontDescriptor: nil)
        let font: UIFont = fontConfig.font
        let fontType: StyleFontDescriptor.FontType = fontConfig.fontType
        let dynamicTypeTextStyle: UIFont.TextStyle? = fontConfig.dynamicTypeTextStyle

        applyFontAttribute(attrString, font: font)
//        applyForegroundColorAttribute(attrString, color: color)
        applyKerningAttribute(attrString, kern: kern, font: font, fontType: fontType)
        applyParagraphAttribute(attrString, lineHeight: lineHeight, font: font, fontType: fontType, dynamicTypeTextStyle: dynamicTypeTextStyle)
//        applyDecorationAttributes(&attrString, decorations: decorations)

        return attrString
    }

    private func getFontConfig(layoutInfo: TypographyModel, lastRegisteredFontDescriptor: StyleFontDescriptor?) -> FontConfig {
        let font: UIFont
        var fontType: StyleFontDescriptor.FontType = layoutInfo.styleFontDescriptor.fontType
        var dynamicTypeTextStyle: UIFont.TextStyle? = nil

        switch layoutInfo.styleFontDescriptor.fontType {
        case .raw:
            // If new font has not loaded and been registered yet, use previous font stored in `lastRegisteredFontDescriptor` until new one is loaded
            if let postscriptName: String = layoutInfo.styleFontDescriptor.getRawPostscriptName() {

                font = layoutInfo.styleFontDescriptor.createFont()
                dynamicTypeTextStyle = layoutInfo.styleFontDescriptor.getDynamicTypographyTextStyle()

                // Load font url
                if !UIFont.isLoaded(postScriptName: postscriptName) {

                }

            }
//            else if let prevFontDescriptor = lastRegisteredFontDescriptor {
//                font = prevFontDescriptor.createFont()
//                dynamicTypeTextStyle = prevFontDescriptor.getDynamicTypographyTextStyle()
//                fontType = prevFontDescriptor.fontType
//            }
            else {
                font = layoutInfo.styleFontDescriptor.createFont()
                dynamicTypeTextStyle = layoutInfo.styleFontDescriptor.getDynamicTypographyTextStyle()
            }
        case .system:
            font = layoutInfo.styleFontDescriptor.createFont()
        case .systemStyle:
            // This strips NSCTFontSizeCategoryAttribute & NSCTFontUIUsageAttribute as they are causing the CATextLayer
            // to clip certain content size categories
            font = layoutInfo.styleFontDescriptor.createDetachedCopy().createFont()
        }

        return .init(font: font, fontType: fontType, dynamicTypeTextStyle: dynamicTypeTextStyle)
    }

    func applyFontAttribute(_ attrString: NSMutableAttributedString, font: UIFont) {
        attrString.addAttribute(NSAttributedString.Key.font, value: font, range: NSRange(location: 0, length: attrString.length))
    }

    func applyKerningAttribute(_ attrString: NSMutableAttributedString, kern: StyleFloat?, font: UIFont, fontType: StyleFontDescriptor.FontType) {
        if let kern = kern {
            let adjustedKern: CGFloat = StyleTextViewModel.getAdjustedKerning(font: font, letterSpacing: kern, isSystemFont: fontType.isAnySystem)
            if attrString.length > 1 {
                attrString.addAttribute(NSAttributedString.Key.kern, value: adjustedKern, range: NSRange(location: 0, length: attrString.length - 1))
            }
        } else {
            if fontType.isAnySystem {
                let adjustedKern = StyleTextViewModel.getSystemFontKerningAdjustment(fontSize: font.pointSize, kerning: 0)
                attrString.addAttribute(NSAttributedString.Key.kern, value: adjustedKern, range: NSRange(location: attrString.length - 1, length: 1))
            }
        }
    }

    func applyDecorationAttributes(_ attrString: NSMutableAttributedString, decorations: [TextDecoration]?) {
        if let decorations = decorations {
            if decorations.contains(.underline) {
                attrString.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: attrString.length))
            } else {
                attrString.removeAttribute(NSAttributedString.Key.underlineStyle, range: NSRange(location: 0, length: attrString.length))
            }

            if decorations.contains(.lineThrough) {
                attrString.addAttribute(NSAttributedString.Key.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: attrString.length))
            } else {
                attrString.removeAttribute(NSAttributedString.Key.strikethroughStyle, range: NSRange(location: 0, length: attrString.length))
            }
        }
    }

    func applyParagraphAttribute(
        _ attrString: NSMutableAttributedString,
//        alignment: Alignment.Horizontal,
        lineHeight: StyleFloat?,
        font: UIFont,
        fontType: StyleFontDescriptor.FontType,
        dynamicTypeTextStyle: UIFont.TextStyle?
    ) {
        var paragraph: NSMutableParagraphStyle = .init()
//        paragraph.alignment = alignment.textAlignment
        paragraph.lineBreakStrategy = .pushOut
        applyLineHeightAttributes(paragraph, lineHeight: lineHeight, font: font, fontType: fontType, dynamicTypeTextStyle: dynamicTypeTextStyle)

        attrString.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: attrString.length))
    }

    private func applyLineHeightAttributes(
        _ paragraph: NSMutableParagraphStyle,
        lineHeight: StyleFloat?,
        font: UIFont,
        fontType: StyleFontDescriptor.FontType,
        dynamicTypeTextStyle: UIFont.TextStyle?
    ) {

        guard let lineHeight else { return }
        var lineHeightMultiple: CGFloat = Self.getLineHeightMultiple(lineHeight: lineHeight, font: font)
        if lineHeight.isAuto {
            switch fontType {
            case .system:
                lineHeightMultiple = StyleTextViewModel.getSystemFontAutoLineHeightMultipleAdjusted(font: font)
            case .systemStyle(let textStyle, _, _, _, _):
                lineHeightMultiple = StyleTextViewModel.getSystemStyleAutoLineHeightMultipleAdjusted(font: font, textStyle: textStyle)
            case .raw:
                lineHeightMultiple = 1
            }
        }

        paragraph.lineHeightMultiple = lineHeightMultiple
        paragraph.minimumLineHeight = font.lineHeight * lineHeightMultiple
        paragraph.maximumLineHeight = font.lineHeight * lineHeightMultiple
    }

    static func getLineHeightMultiple(lineHeight: StyleFloat, font: UIFont) -> CGFloat {
        if lineHeight.isAuto {
            return 1
        } else {
            var val: CGFloat
            if lineHeight.isPercent {
                val = ((lineHeight.value / 100) * font.pointSize) / font.lineHeight
            } else {
                val = lineHeight.value / font.lineHeight
            }
            // avoid setting to 0, otherwise it will show larger line height
            return max(0.0000001, val)
        }
    }
}

// MARK: System Font Adjustments
extension TypographyModel {

    // MARK: Kerning Adjustment

    static func getAdjustedKerning(font: UIFont, letterSpacing: StyleFloat, isSystemFont: Bool) -> CGFloat {
        let fontSize: CGFloat = (font.pointSize)

        var adjustedKern: CGFloat = 0.0
        if letterSpacing.isPercent {
            adjustedKern = (fontSize * (letterSpacing.value / 100.0))
        } else if letterSpacing.value != nil {
            adjustedKern = letterSpacing.value
        }

        // this fixes a bug with attributed string kerning not applying when set to 0
        if adjustedKern == 0 {
            adjustedKern = 0.0000000001
        }

        if isSystemFont {
            let addedSystemFontKern = StyleTextViewModel.getSystemFontKerningAdjustment(fontSize: fontSize, kerning: adjustedKern)

            adjustedKern = adjustedKern + addedSystemFontKern
        }

        return adjustedKern
    }

    static func getSystemFontKerningAdjustment(fontSize: CGFloat, kerning: CGFloat) -> CGFloat {
#if targetEnvironment(macCatalyst)

        let fontSizeAsInt: Int = Int(fontSize)
        let adjustments: [CGFloat] = [0.0, 0.0, 0.0, 0.0, 0.0 ,-0.070, -0.133, -0.194, -0.220, -0.244, -0.248, -0.259, -0.259, -0.274, -0.277, -0.289, -0.304, -0.216, -0.112]

        guard adjustments.indices.contains(fontSizeAsInt - 1) else { return kerning }
        let adjust: CGFloat = adjustments[fontSizeAsInt - 1]
        return kerning + adjust
#else
        return kerning
#endif
    }

    // MARK: Line Height Adjustment - System Fonts

    static func getSystemFontAutoLineHeightMultipleAdjusted(font: UIFont) -> CGFloat {
#if targetEnvironment(macCatalyst)
        let fontSize: Int = Int(font.pointSize)

        guard let fontMetric: iOSFontMetrics.FontMetric = iOSFontMetrics.SystemFont.getMetrics(forSize: fontSize) else {
            return 1.0
        }

        let multiple: CGFloat = fontMetric.lineHeight / font.lineHeight
        //        print("[text-node] size: \(fontSize) iOS lineHeight: \(iOSSystemFontLineHeight), macOS lineHeight: \(font.lineHeight), multiple: \(multiple)")
        return multiple
#else
        return 1.0
#endif
    }

    static func getSystemFontAutoLineHeightAdjusted(font: UIFont) -> CGFloat {
#if targetEnvironment(macCatalyst)
        let fontSize: Int = Int(font.pointSize)

        guard let fontMetric: iOSFontMetrics.FontMetric = iOSFontMetrics.SystemFont.getMetrics(forSize: fontSize) else {
            return font.lineHeight * 1.013
        }
        return fontMetric.lineHeight
#else
        return font.lineHeight
#endif
    }

    // MARK: Line Height Adjustment - System Styles

    static func getSystemStyleAutoLineHeightMultipleAdjusted(font: UIFont, textStyle: UIFont.TextStyle) -> CGFloat {
        let desiredLineHeight: CGFloat = iOSFontMetrics.SystemStyle.getMetrics(forTextStyle: textStyle)?.lineHeight ?? textStyle.iOSDefaultFontLineHeight
        let multiple: CGFloat = desiredLineHeight / font.lineHeight
        print("[text-node] iOS desiredLineHeight: \(desiredLineHeight), font.lineHeight: \(font.lineHeight), multiple: \(multiple)")
        return multiple
    }

}

extension UIFont {
    static func isLoaded(postScriptName: String) -> Bool {
        // nil font means it is not loaded
        return UIFont(name: postScriptName, size: 16) != nil
    }
}



