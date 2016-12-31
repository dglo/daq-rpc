class JSONRPCFormatter: Formatter {
    func extractRequest(_ msg: Any?) throws -> MethodCall {
        guard let map = msg as? [String: Any?] else {
            throw I3RPCError.Format("Request \(msg.debugDescription) is not" +
                                      " a Dictionary")
        }

        guard let elem = map["id"] else {
            throw I3RPCError.Format("Request does not contain" +
                                      " \"id\" entry")
        }

        guard let id = elem else {
            throw I3RPCError.Format("Request contains nil" +
                                      " \"id\" entry")
        }

        guard let methodName = map["method"] as! String? else {
            throw I3RPCError.Format("Request does not contain" +
                                      " \"method\" entry")
        }

        if map["params"] == nil {
            throw I3RPCError.Format("Request does not contain" +
                                      " \"params\" entry")
        }

        let params: [Any?]
        if let tmpparm = map["params"] as? [Any?] {
            params = tmpparm
        } else {
            params = []
        }

        return MethodCall(id: id, name: methodName, params: params)
    }

    func extractResult(_ msg: Any) throws -> Any? {
        guard let map = msg as? [String: Any?] else {
            throw I3RPCError.Format("Result \(msg) is not a Dictionary")
        }

        guard let elem = map["id"] else {
            throw I3RPCError.Format("Request does not contain" +
                                      " \"id\" entry")
        }

        guard let id = elem else {
            throw I3RPCError.Format("Request contains nil" +
                                      " \"id\" entry")
        }

        if let errvalue = map["error"] as? String {
            let etype = type(of: errvalue)
            throw I3RPCError.Format("ERROR: ID#\(id) \(errvalue)<\(etype)>")
        }

        guard let result = map["result"] else {
            throw I3RPCError.Format("Dictionary (ID#\(id)) does not contain" +
                                      " \"error\" or \"result\" entry")
        }

        return result
    }

    func formatError(request: MethodCall, error: String) throws -> Any {
        return formatReturnMap(request: request, result: nil, error: error)
    }

    func formatRequest(_ methodName: String,
                       params: [Any?]) throws -> Any {
        var map = [String: Any?]()
        map["id"] = IDFactory.get()
        map["method"] = methodName
        map["params"] = params
        return map as Any
    }

    func formatResult(request: MethodCall,
                      result: Any?) throws -> Any {
        return formatReturnMap(request: request, result: result, error: nil)
    }

    func formatReturnMap(request: MethodCall, result: Any?,
                         error: String?) -> Any {
        var map = [String: Any?]()
        map["id"] = request.id
        map["result"] = result as Any?
        map["error"] = error as Any?
        return map as Any
    }
}
