import Foundation

class Server {
    private let transport: Transport
    private var encoder: Encoder
    private let msgproc: MessageProcessor

    init(encoder: Encoder, msgproc: MessageProcessor,
         transport: Transport) throws {
        self.encoder = encoder
        self.msgproc = msgproc
        self.transport = transport
    }

    func start(port: UInt16) throws {
        if !transport.isServer {
            throw I3RPCError.Transport("Cannot start single-server")
        }

        try transport.startServer(port: port, msgproc: msgproc)
    }

    func stop() throws {
        transport.stop()
    }

    func waitForStop() throws {
        transport.waitForStop()
    }
}
