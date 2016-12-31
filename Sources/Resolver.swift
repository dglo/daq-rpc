enum Resolution {
    case UnknownMethod
    case NilResult
    case Result(_: Any)
    case Failed(error: String)
}

protocol Resolver {
    func execute(methodName: String, parameters: [Any?]) -> Resolution
}
