import Foundation

import daq_common

class IDFactory {
    private static var nextID = 1
    private static var mutex = Mutex()

    public static func get() -> Int {
        mutex.lock()
        defer {
            mutex.unlock()
        }

        let id = nextID
        nextID += 1
        return id
    }
}
