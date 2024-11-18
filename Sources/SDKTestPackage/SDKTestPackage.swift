// The Swift Programming Language
// https://docs.swift.org/swift-book

import sdk_framework

public final class SDKTestPackage {
    public static let shared: SDKTestPackage = .init()
    public static func useFromSDKFrameworkSingleton() {
        shared.useFromSDKFramework()
    }

    public init() { }
    public func useFromSDKFramework() {
        TestSDK.printVersion()
        TestSDK.shared.printVersion()
        let string = "4.2069"
        print("Running function with result: \(TestSDK.shared.useToFloatFunctionFromPlayHelpers(string: string) ?? -69.0)")
    }
}
