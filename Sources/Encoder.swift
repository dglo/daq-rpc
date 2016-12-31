public protocol Encoder {
    func decode(_ rawbytes: [UInt8]) throws -> Any?
    func encode(_ object: Any?) throws -> [UInt8]
}
