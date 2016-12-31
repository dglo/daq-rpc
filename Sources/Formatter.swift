public protocol Formatter {
    func extractRequest(_ msg: Any?) throws -> MethodCall
    func extractResult(_ msg: Any) throws -> Any?
    func formatError(request: MethodCall, error: String) throws -> Any
    func formatRequest(_ methodName: String,
                       params: [Any?]) throws -> Any
    func formatResult(request: MethodCall,
                      result: Any?) throws -> Any
}
