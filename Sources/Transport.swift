import Foundation

protocol Transport {
    var modeString: String { get}
    var isServer: Bool { get }
    func getNextConnection(addr: inout sockaddr,
                           len: inout socklen_t) throws -> Int32
    func sendBytes(_ message: [UInt8]) throws
    func startClient(host: String, port: UInt16) throws
    func startServer(port: UInt16, msgproc: MessageProcessor) throws
    func startServer(port: UInt16, msgproc: MessageProcessor,
                     backlog: Int32) throws
    func stop()
    func receiveBytes() throws -> [UInt8]
    func waitForStop()
}
