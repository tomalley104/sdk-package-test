@_exported import PlaySDK


struct TestStruct {
    static func doAThing() throws {
        throw PlayRuntimeEngine.BuildErrors.couldNotCreateView
    }
}
