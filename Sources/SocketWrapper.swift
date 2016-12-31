import Foundation

enum SocketResult {
case EndOfFile
case Error(Int)
case Result([UInt8])
case Success
}

private let Z32: Int32 = 0
#if os(Linux)
private let FDSET_ZEROS =
      (Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32,
       Z32, Z32)
#else
private let FDSET_ZEROS =
      (Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32,
       Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32, Z32,
       Z32, Z32, Z32, Z32)
#endif

class SocketWrapper {
    private let NO_SOCKET = Int32.min

    private var sock: Int32

    init(_ sock: Int32) {
        self.sock = sock
    }

    func closeSocket() {
        close(sock)
        sock = NO_SOCKET
    }

    func isOpen() -> Bool {
        return sock != NO_SOCKET
    }

    func receiveBytes() -> SocketResult {
        let numFd = sock + 1
        var socklist = fd_set(fds_bits: FDSET_ZEROS)
        var timeout = timeval(tv_sec: 1, tv_usec: 0)

        ////////////////
        var lendata = [UInt8](repeating: 0, count: 4)

        var lenlen = 0
        while lenlen < 4 {
            let tmplen = recv(sock, &lendata[lenlen], 4, 0)
            if tmplen < 0 {
                return .Error(tmplen)
            } else if tmplen == 0 {
                return .EndOfFile
            }

            lenlen += tmplen
        }

        var len: Int = 0
        for byte in lendata {
            len = (len << 8) + Int(byte)
        }
        var rawdata: [UInt8] = Array(repeating: 0, count: len)

        let bufferSize: Int
        if len < 4096 {
            bufferSize = len
        } else {
            bufferSize = 4096
        }

        var datalen = 0
        while datalen < len {
            let tmplen = recv(sock, &rawdata[datalen], bufferSize, 0)
            if tmplen < 0 {
                return .Error(tmplen)
            } else if tmplen == 0 {
                return .EndOfFile
            }

            datalen += tmplen
        }

        return .Result(Array(rawdata[0..<datalen]))
    }

    func sendBytes(_ message: [UInt8]) -> SocketResult {
        let lenbytes: [UInt8] = [
            UInt8((message.count >> 24) & 0xff),
            UInt8((message.count >> 16) & 0xff),
            UInt8((message.count >> 8) & 0xff),
            UInt8((message.count >> 0) & 0xff),
        ]

        let lerror = send(sock, lenbytes, lenbytes.count, 0)
        if lerror < 0 {
            return .Error(lerror)
        }

        let error = send(sock, message, message.count, 0)
        if error < 0 {
            return .Error(error)
        }
        return .Success
    }
}
