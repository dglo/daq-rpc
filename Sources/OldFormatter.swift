class OldFormatter: Formatter {
    func extractRequest(_ msg: Any?) throws -> MethodCall {
        guard let map = msg as? [String: Any?] else {
            throw I3RPCError.Format("Message is not a Dictionary")
        }

        guard let methodName = map["method"] as! String? else {
            throw I3RPCError.Format("Dictionary does not contain" +
                                      " \"method\" entry")
        }

        guard let params = map["args"] as! [Any]? else {
            throw I3RPCError.Format("Dictionary does not contain" +
                                      " \"args\" entry")
        }

        return MethodCall(id: 0 as Any, name: methodName, params: params)
    }

    func extractResult(_ msg: Any) throws -> Any? {
        guard let response = msg as? [String: Any?] else {
            throw I3RPCError.Format("Expected Dictionary, not \(msg)")
        }

        if let error = response["error"] {
            if let errmsg = error as! String? {
                throw I3RPCError.Format(errmsg)
            } else {
                throw I3RPCError.Format("Error should be string, not \(error)")
            }
        }

        guard let result = response["result"] else {
            throw I3RPCError.Format("Result not found in \(response)")
        }

        return result
    }

    func formatError(request: MethodCall, error: String) throws -> Any {
        let map = ["error": error as Any]
        return map as Any
    }

    func formatRequest(_ methodName: String,
                       params: [Any?]) -> Any {
        var map = [String: Any?]()
        map["method"] = methodName
        map["args"] = params
        return map as Any
    }

    func formatResult(request: MethodCall,
                      result: Any?) throws -> Any {
        let map = ["result": result as Any?]
        return map as Any
    }
}
