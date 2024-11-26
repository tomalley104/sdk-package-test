//
//  File.swift
//  
//
//  Created by Eric Eng on 11/13/24.
//

import Foundation
import UIKit
import SwiftUI

// TODO: Future allow SwiftUI Children to be inserted
open class UIKitBaseViewControllerWithChildren<VariableContainerType, ClassType, Content: View>: UIKitBaseViewController<VariableContainerType, ClassType> {
    var vc: UIHostingController<Content>?

    public func withChildren(_ content: Content) -> Self {
        if let vc {
            vc.rootView = content
            vc.view.frame.size = vc.view.intrinsicContentSize
            return self
        }
        let vc = vc ?? .init(rootView: content)
        self.vc =  vc
        self.addChild(vc)
        self.view.addSubview(vc.view)
        vc.didMove(toParent: self)
        vc.view.frame.size = vc.view.intrinsicContentSize
        return self
    }
}

// EXAMPLE FOR SWIFTUI
/**

public struct SUISearch<Content: View>: SwiftUIBaseViewController {
    public typealias UIViewControllerType = UIKSearch<Content>
    public typealias ClassType = Self

    public var variables: UIKSearch<Content>.AvailProps? = .init()
    public var keyPathToPlayId: [AnyHashable: String] = [:]
    public var playIdToUpdateCall: [String : (Any?) -> Void] = [:]

    var content: Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content()
        print("____ content", Content.self)
    }

    public func makeUIViewController(context: Context) -> UIViewControllerType {
        let vc = UIViewControllerType()
        vc.withChildren(content)
        print("*** make controller")

        return vc
    }

    public func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        print("*** update controller")
        uiViewController.withChildren(content)
        Self.updateUIViewController(uiViewController, suiController: self) { }
    }
}
*/
