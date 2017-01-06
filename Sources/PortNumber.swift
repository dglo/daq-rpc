#if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
    import Darwin
#else
    import Glibc
#endif
import Dispatch

import daq_common

public class PortNumber {
    private static var nextPort: UInt16 = 12000
    private static var mutex = Mutex()

    public static func next() -> UInt16 {
        mutex.lock()
        defer {
            mutex.unlock()
        }

        let port = nextPort
        nextPort += 1
        return port
    }
}
