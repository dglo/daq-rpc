import Foundation
#if os(Linux)
  import Dispatch
#endif

class SocketTransport: ClientServerTransport {
    var mode: TransportMode

    private let BACKLOG: Int32 = 5
    private let MAX_FAILED = 15

    private let NO_SOCKET = Int32.min

    private var msgproc: MessageProcessor
    private var srvrSock: Int32
    private var conn: SocketWrapper
    private var running: Bool

    init(msgproc: MessageProcessor) {
        self.mode = TransportMode.Unknown

        self.msgproc = msgproc
        self.srvrSock = NO_SOCKET
        self.conn = SocketWrapper(NO_SOCKET)
        self.running = false
    }

    var isServer: Bool {
        return true
    }

    func clearMode() {
        mode = .Unknown
    }

    func setMode(_ newMode: TransportMode) throws {
        mode = newMode
    }

#if os(Linux)
    private func fixSocketType(_ socktype: __socket_type) -> Int32 {
        return Int32(bitPattern: socktype.rawValue)
    }

    private func createAIHints(flags: Int32, family: Int32,
                               socktype: __socket_type) -> addrinfo {
        return addrinfo(
                ai_flags: flags,
                ai_family: family,
                ai_socktype: fixSocketType(socktype),
                ai_protocol: 0,
                ai_addrlen: 0,
                ai_addr: nil,
                ai_canonname: nil,
                ai_next: nil)
    }
#else
    private func fixSocketType(_ socktype: Int32) -> Int32 {
        return socktype
    }

    private func createAIHints(flags: Int32, family: Int32,
                               socktype: Int32) -> addrinfo {
        return addrinfo(
                ai_flags: flags,
                ai_family: family,
                ai_socktype: SOCK_STREAM,
                ai_protocol: 0,
                ai_addrlen: 0,
                ai_canonname: nil,
                ai_addr: nil,
                ai_next: nil)
    }
#endif

    private func bindSocket(_ port: UInt16) throws {
        var error: Int32 = 0

        var hints = createAIHints(flags: AI_PASSIVE, family: AF_INET,
                                  socktype: SOCK_STREAM)

        var infoopt: UnsafeMutablePointer<addrinfo>? = nil

        error = getaddrinfo(nil, "\(port)", &hints, &infoopt)
        if error < 0 {
            try throwError("Cannot get address info for port \(port)")
        }

        var bound = false
        while infoopt != nil {
            guard let info = infoopt else {
                break
            }
            //print("info \(info.pointee)")

            error = bind(srvrSock, info.pointee.ai_addr,
                         info.pointee.ai_addrlen)
            if error == 0 {
                bound = true
                break
            }

            infoopt = info.pointee.ai_next
        }
        freeaddrinfo(infoopt)

        if !bound {
            try throwError("Cannot bind server socket to port \(port)")
        }
    }

    func getNextConnection(addr: inout sockaddr,
                           len: inout socklen_t) throws -> Int32 {
        if !isServer {
            throw I3RPCError.Transport("Not a server connection")
        }

        let conn = accept(srvrSock, &addr, &len)
        if conn < 0 {
            try throwError("Cannot accept new connection")
        }

        return conn
    }

    private func listenSocket(_ backlog: Int32) throws {
        let error = listen(srvrSock, backlog)
        if error < 0 {
            close(srvrSock)
            srvrSock = NO_SOCKET
            try throwError("Cannot listen to server socket")
        }
    }

    private func logError(_ message: String, includeErrno: Bool = true) {
        let extra: String
        if !includeErrno {
            extra = ""
        } else {
            let strError = String(utf8String: strerror(errno)) ??
                           "Unknown error code"
            extra = " (error=\(errno) \(strError))"
        }

        print("ERROR: \(message)\(extra)")
    }

    private func loop(msgproc: MessageProcessor) {
        var failed = 0

        running = true
        while running {
            var addr = sockaddr()
            var addrlen: socklen_t = 0

            let conn: Int32
            do {
                conn = try getNextConnection(addr: &addr, len: &addrlen)
                failed = 0
            } catch {
                logError("\(error)", includeErrno: false)
                failed += 1
                if failed > MAX_FAILED {

                    break
                }
                continue
            }

            if !running {
                break
            }

            let wrk = SocketWorker(msgproc: msgproc)
            wrk.push(conn: SocketWrapper(conn), addr: addr)
        }
    }

    private func open(host: String, port: UInt16) throws -> Int32 {
        var error: Int32 = 0

        var hints = createAIHints(flags: AI_PASSIVE, family: AF_UNSPEC,
                                  socktype: SOCK_STREAM)

        var infoopt: UnsafeMutablePointer<addrinfo>? = nil

        error = getaddrinfo(host, "\(port)", &hints, &infoopt)
        if error < 0 {
            try throwError("Cannot get address info for \(host):\(port)")
        }

        var conn: Int32 = 0

        var connected = false
        while infoopt != nil {
            guard let info = infoopt else {
                break
            }

            conn = socket(info.pointee.ai_family,
                          info.pointee.ai_socktype,
                          info.pointee.ai_protocol)
            if conn < 0 {
                continue
            }

            error = connect(conn, info.pointee.ai_addr,
                            info.pointee.ai_addrlen)
            if error == 0 {
                connected = true
                break
            }

            close(conn)
            infoopt = info.pointee.ai_next
        }
        freeaddrinfo(infoopt)
        if !connected {
            try throwError("Cannot open socket for \(host):\(port)")
        }

        return conn
    }

    private func openServer() throws -> Int32 {
        let serverSocket = socket(AF_INET, fixSocketType(SOCK_STREAM), 0)
        if serverSocket < 0 {
            try throwError("Cannot create server socket")
        }

        return serverSocket
    }

    func receiveBytes() throws -> [UInt8] {
        try checkStarted()

        switch conn.receiveBytes() {
        case .Error(let error):
            throw I3RPCError.Transport("ERROR: Cannot receive data: \(error)")
        case .Result(let data):
            return data
        default:
            try throwError("Unexpected return value from receiveBytes")
        }

        throw I3RPCError.Transport("This should never be thrown")
    }

    func sendBytes(_ message: [UInt8]) throws {
        switch conn.sendBytes(message) {
        case .Error(let error):
            throw I3RPCError.Transport("ERROR: Cannot write message*" +
                                         "\(message.count): \(error)")
        case .Success:
            break
        default:
            try throwError("Unexpected return value from sendBytes")
        }
    }

    func startClient(host: String, port: UInt16) throws {
        if conn.isOpen() {
            throw I3RPCError.Transport("Client is already running!")
        }

        try setClient()

        let sock = try open(host: host, port: port)
        conn = SocketWrapper(sock)
    }

    func startServer(port: UInt16, msgproc: MessageProcessor) throws {
        try startServer(port: port, msgproc: msgproc, backlog: BACKLOG)
    }

    func startServer(port: UInt16, msgproc: MessageProcessor,
                     backlog: Int32) throws {
        if srvrSock != NO_SOCKET {
            throw I3RPCError.Transport("Server is already running!")
        }

        try setServer()

        srvrSock = try openServer()

        var flag: Int = 1
        let error = setsockopt(srvrSock, SOL_SOCKET, SO_REUSEADDR, &flag,
                               socklen_t(MemoryLayout<Int>.size))
        if error < 0 {
            close(srvrSock)
            try throwError("Cannot make server socket reusable")
        }

        try bindSocket(port)
        try listenSocket(backlog)

        DispatchQueue.global(qos: .utility).async {
            self.loop(msgproc: msgproc)
        }

        while !running {
            usleep(1000)
        }
    }

    func startServer(port: Int) {
        fatalError("Unimplemented(SocketTransport.startServer)")
    }

    func stop() {
        if conn.isOpen() {
            conn.closeSocket()
        }
        if srvrSock != NO_SOCKET {
            close(srvrSock)
            srvrSock = NO_SOCKET
        }

        clearMode()
    }

    private func throwError(_ message: String) throws {
        let strError = String(utf8String: strerror(errno)) ??
                       "Unknown error code"
        throw I3RPCError.Transport("ERROR: \(message)" +
                                   " (error=\(errno) \(strError))")
    }

    func waitForStop() {
        while running {
            usleep(1000)
        }
    }
}
