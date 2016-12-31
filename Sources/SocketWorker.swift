import Foundation

class SocketWorker {
    private let msgproc: MessageProcessor

    init(msgproc: MessageProcessor) {
        self.msgproc = msgproc
    }

    private func handle(conn: SocketWrapper, addr: sockaddr) -> Bool {
        var data: [UInt8]
        switch conn.receiveBytes() {
        case .EndOfFile:
            print("Closed conn \(conn)")
            return false
        case .Error(let error):
            print("Cannot receive data: \(error)")
            return false
        case .Result(let result):
            data = result
        default:
            printError("Unexpected return value from receiveBytes")
            return false
        }

        let reply = msgproc.processMessage(msg: data)

        switch conn.sendBytes(reply) {
        case .Error(let error):
            print("Cannot write reply: \(error)")
            return false
        case .Success:
            return true
        default:
            printError("Unexpected return value from sendBytes")
            return false
        }
    }

    private func printError(_ message: String) {
        let strError = String(utf8String: strerror(errno)) ??
                       "Unknown error code"
        print("ERROR: \(message) (error=\(errno) \(strError))")
    }

    func push(conn: SocketWrapper, addr: sockaddr) {
        DispatchQueue.global(qos: .utility).async {
            var looping = true
            while looping {
                looping = self.handle(conn: conn, addr: addr)
            }
            conn.closeSocket()
        }
    }
}
