public class Client {
    private var encoder: Encoder
    private var formatter: Formatter
    private var transport: Transport

    public init(encoder: Encoder, formatter: Formatter, transport: Transport) {
        self.encoder = encoder
        self.formatter = formatter
        self.transport = transport
    }

    func close() {
        transport.stop()
    }

    func execute(_ methodName: String,
                 params: [Any?]) throws -> Any? {
        let req = try formatter.formatRequest(methodName, params: params)

        try transport.sendBytes(encoder.encode(req))

        let rawbytes = try transport.receiveBytes()
        let rawobj = try encoder.decode(rawbytes)
        guard let nonnil = rawobj else {
            throw I3RPCError.Decode("Expected non-nil object, not" +
                                      " \(rawobj)")
        }

        return try formatter.extractResult(nonnil)
    }

    func start(host: String, port: UInt16) throws {
        try transport.startClient(host: host, port: port)
    }
}
