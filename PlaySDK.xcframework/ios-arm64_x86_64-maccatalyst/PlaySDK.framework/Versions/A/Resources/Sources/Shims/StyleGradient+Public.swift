//
//  StyleGradient+Public.swift
//  PlaySDK
//
//  Created by Tom OMalley on 11/19/24.
//

import Foundation
import UIKit
import Combine

@_implementationOnly import PlaySheets

public struct PlayGradient {

    public var colors: [UIColor] { _styleGradient.colors }
    public var locations: [NSNumber] { _styleGradient.locations }
    public var lastValidHueList: [CGFloat?] { _styleGradient.lastValidHueList }
    public var endPoint: CGPoint { _styleGradient.endPoint }
    public var startPoint: CGPoint { _styleGradient.startPoint }
    public var type: CAGradientLayerType { _styleGradient.type }
    public var scale: CGFloat { _styleGradient.scale }
    public var rotation: CGFloat { _styleGradient.rotation }

    internal let _styleGradient: StyleFill.StyleGradient

    public init(type: CAGradientLayerType = .axial,
                colors: [UIColor],
                locations: [NSNumber],
                lastValidHueList: [CGFloat?]? = nil,
                startPoint: CGPoint,
                endPoint: CGPoint,
                scale: CGFloat = 100.0,
                rotation: CGFloat = 0.0) {
        self._styleGradient = .init(
            type: type,
            colors: colors,
            locations: locations,
            lastValidHueList: lastValidHueList,
            startPoint: startPoint,
            endPoint: endPoint,
            scale: scale,
            rotation: rotation
        )
    }

    var cgColors: [CGColor] { _styleGradient.cgColors }

    public func applyTo(_ view: UIView) {
        _styleGradient.applyTo(view)
    }

    /// Creates and returns new `CAGradientLayer`
    func layer() -> CAGradientLayer {
        _styleGradient.layer()
    }
}

// MARK: StyleGradient Additions
// FIXME: move to PlaySheets

extension StyleFill.StyleGradient {
    var cgColors: [CGColor] { colors.map { $0.cgColor }}

    func applyTo(_ view: UIView) {
        let newLayer = layer()
        newLayer.frame.size = view.frame.size
        view.layer.insertSublayer(newLayer, at: 0)

        if let newLayer = newLayer as? ResizingGradientLayer {
            newLayer.observe(view)
        }
    }

    /// Creates and returns new `CAGradientLayer`
    func layer() -> CAGradientLayer {
        let colorLayer = ResizingGradientLayer()

        var startPoint: CGPoint = .zero
        var endPoint: CGPoint = .zero
        let scale: CGFloat = scale / 100

        if type == .axial {
            // handle linear rotation
            let x: Double = rotation / 360.0
            let a = pow(sinf(Float(2.0 * Double.pi * ((x + 0.75) / 2.0))),2.0);
            let b = pow(sinf(Float(2*Double.pi*((x+0.0)/2))),2);
            let c = pow(sinf(Float(2*Double.pi*((x+0.25)/2))),2);
            let d = pow(sinf(Float(2*Double.pi*((x+0.5)/2))),2);

            startPoint = CGPoint(x: CGFloat(a),y:CGFloat(b))
            endPoint = CGPoint(x: CGFloat(c),y: CGFloat(d))

        } else if type == .radial {
            startPoint = self.startPoint
            endPoint = self.endPoint
        }

        // scale the start/endpoints
        let startXDiff = startPoint.x - 0.5
        let startYDiff = startPoint.y - 0.5

        let endXDiff = endPoint.x - 0.5
        let endYDiff = endPoint.y - 0.5

        startPoint = .init(x: 0.5 + (startXDiff * scale), y: 0.5 + (startYDiff * scale))
        endPoint = .init(x: 0.5 + (endXDiff * scale), y: 0.5 + (endYDiff * scale))

        // assign to color layer
        colorLayer.type = self.type
        colorLayer.colors = self.colors.map({ $0.p3Display.cgColor })
        colorLayer.locations = locations
        colorLayer.startPoint = startPoint
        colorLayer.endPoint = endPoint

        colorLayer.backgroundColor = UIColor.clear.cgColor

        return colorLayer
    }
}

class ResizingGradientLayer: CAGradientLayer {
    private var _dispose: Set<AnyCancellable> = []

    func observe(_ view: UIView) {
        view.publisher(for: \.frame).dropFirst().sink { [weak self] val in
            self?.frame.size = val.size
        }.store(in: &_dispose)

        view.publisher(for: \.bounds).dropFirst().sink { [weak self] val in
            self?.frame.size = val.size
        }.store(in: &_dispose)
    }

    deinit {
        print("deinit layer")
    }
}


