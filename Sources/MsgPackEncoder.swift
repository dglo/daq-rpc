import Foundation

class MsgPackEncoder: Encoder {
    func decode(_ rawbytes: [UInt8]) throws -> Any? {
        let data = Data(rawbytes)
        return try data.unpack()
    }

    func encode(_ object: Any?) throws -> [UInt8] {
        var data = Data()
        let _ = try data.pack(object)

        // XXX should switch RPC code to use Data
        var bytes = [UInt8]()
        for b in data {
            bytes.append(b)
        }

        return bytes
    }
}
