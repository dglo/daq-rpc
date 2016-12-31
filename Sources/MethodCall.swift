public class MethodCall {
    static let UNKNOWN = MethodCall(id: 0 as Any, name: "UNKNOWN",
                                    params: [Any?]())

    private(set) var id: Any
    private(set) var name: String
    private(set) var params: [Any?]

    init(id: Any, name: String, params: [Any?]) {
        self.id = id
        self.name = name
        self.params = params
    }

    var debugDescription: String {
        return "MethodCall[\(id) \(name)(\(params))"
    }
}
