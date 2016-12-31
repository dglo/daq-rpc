import Foundation

enum TransportMode {
case Unknown, Server, Client
}

protocol ClientServerTransport: Transport {
    var mode: TransportMode { get }

    func setMode(_ newMode: TransportMode) throws
}

extension ClientServerTransport {
    var modeString: String {
        switch mode {
        case .Unknown:
            return "Unknown"
        case .Server:
            return "Server"
        case .Client:
            return "Client"
        }
    }

    var isClient: Bool {
        return mode == .Client
    }

    var isServer: Bool {
        return mode == .Server
    }

    var isStarted: Bool {
        return mode != .Unknown
    }

    func checkStarted() throws {
        if mode == .Unknown {
            throw I3RPCError.Transport("Transport has not been started!")
        }
    }

    func clearMode() throws {
        throw I3RPCError.Transport("Unimplemented(clearMode)")
    }

    func getNextConnection(addr: inout sockaddr,
                           len: inout socklen_t) throws -> Int32 {
        throw I3RPCError.Transport("Unimplemented(getNextConnection)")
    }

    func setClient() throws {
        try setMode(.Client)
    }

    func setMode(_ newMode: TransportMode) throws {
        throw I3RPCError.Transport("Unimplemented(setMode)")
    }

    func setServer() throws {
        try setMode(.Client)
    }
}
