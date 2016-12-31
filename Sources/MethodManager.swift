class MethodManager: MessageProcessor {
    private var resolvers = [Resolver]()

    override func add(resolver: Resolver) {
        resolvers.append(resolver)
    }

    override func processOne(msg: MethodCall) throws -> Any? {
        for resolver in resolvers {
            let resolution = resolver.execute(methodName: msg.name,
                                              parameters: msg.params)
            switch resolution {
            case .UnknownMethod:
                continue
            case .NilResult:
                return nil
            case .Result(let result):
                return result
            case .Failed(let error):
                throw I3RPCError.Execute("\(msg.name)(\(msg.params))" +
                                         " failed: \(error)")
            }
        }

        throw I3RPCError.Execute("Unknown method \(msg.name)")
    }
}
