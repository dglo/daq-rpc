import Foundation

enum MsgPackError: Error {
case NoUTF8String(_: String)
case NotEnoughData
case TooMuchData(_: String)
case UnsupportedValue(_: Any)
}

struct DataByteGenerator {

    let data: Data
    var i: Int

    init(data: Data) {
        self.data = data
        self.i = 0
    }

    mutating func next() throws -> UInt8 {
        if i >= data.count {
            throw MsgPackError.NotEnoughData
        }

        let value: UInt8 = data[Data.Index(i)]
        i += 1

        return value
    }

    mutating func next16() throws -> UInt16 {
        if i + 2 > data.count {
            throw MsgPackError.NotEnoughData
        }

        let uval = UInt16(data[Data.Index(i)]) << 8 +
                   UInt16(data[Data.Index(i + 1)])

        i += 2

        return uval
    }

    mutating func next32() throws -> UInt32 {
        if i + 4 > data.count {
            throw MsgPackError.NotEnoughData
        }

        //return UInt32(try generator.next()) << 24 +
        //       UInt32(try generator.next()) << 16 +
        //       UInt32(try generator.next()) << 8 +
        //       UInt32(try generator.next())
        var uval: UInt32 = 0
        for idx in i...(i+3) {
            uval = (uval << 8) + UInt32(data[Data.Index(idx)])
        }

        i += 4

        return uval
    }

    mutating func next64() throws -> UInt64 {
        if i + 8 > data.count {
            throw MsgPackError.NotEnoughData
        }

        var uval: UInt64 = 0
        for idx in i...(i+7) {
            uval = (uval << 8) + UInt64(data[Data.Index(idx)])
        }

        i += 8

        return uval
    }

    mutating func nextData(length: Int) throws -> Data {
        if i + length > data.count {
            throw MsgPackError.NotEnoughData
        }

        let range = Range(i..<(i + length))
        i += length
        return data.subdata(in: range)
    }
}

// pack strings
public extension Data {
    public mutating func pack(_ obj: Any?) throws -> Data {
        if let nonnil = obj {
            let _ = try pack(nonnil)
        } else {
            var type: UInt8 = UInt8(0xc0)
            self.append(UnsafeBufferPointer(start: &type, count: 1))
        }

        return self
    }

    public mutating func pack(_ any: Any) throws -> Data {
        if let str = any as? String {
            return try self.pack(str)
        } else if let u8 = any as? UInt8 {
            return try self.pack(u8)
        } else if let u16 = any as? UInt16 {
            return try self.pack(u16)
        } else if let u32 = any as? UInt32 {
            return try self.pack(u32)
        } else if let u64 = any as? UInt64 {
            return try self.pack(u64)
        } else if let i8 = any as? Int8 {
            return try self.pack(i8)
        } else if let i16 = any as? Int16 {
            return try self.pack(i16)
        } else if let i32 = any as? Int32 {
            return try self.pack(i32)
        } else if let i64 = any as? Int64 {
            return try self.pack(i64)
        } else if let dbl = any as? Double {
            return try self.pack(dbl)
        } else if let flt = any as? Float {
            return try self.pack(flt)
        } else if let int = any as? Int {
            return try self.pack(int)
        } else if let uint = any as? UInt {
            return try self.pack(uint)
        } else if let char = any as? Character {
            return try self.pack(String(char))
        } else if let bool = any as? Bool {
            return try self.pack(bool)
        } else if let array = any as? [Any?] {
            return try self.pack(array)
/*
        } else if let xset = any as? Set {
            return try self.pack(xset)
*/
        } else if let map = any as? [AnyHashable: Any?] {
            return try self.pack(map)
        } else if let map = any as? [AnyHashable: Any] {
            return try self.pack(map)
        } else {
            throw MsgPackError.UnsupportedValue("Unknown(\(any))")
        }
    }

    public mutating func pack(_ bool: Bool) throws -> Data {
        var type: UInt8 = UInt8(bool ? 0xc3 : 0xc2)
        self.append(UnsafeBufferPointer(start: &type, count: 1))
        return self
    }

    public mutating func pack(_ uint8: UInt8) throws -> Data {
        return try pack(Int(uint8))
    }

    public mutating func pack(_ int8: Int8) throws -> Data {
        return try pack(Int(int8))
    }

    public mutating func pack(_ uint16: UInt16) throws -> Data {
        return try pack(Int(uint16))
    }

    public mutating func pack(_ int16: Int16) throws -> Data {
        return try pack(Int(int16))
    }

    public mutating func pack(_ uint32: UInt32) throws -> Data {
        return try pack(Int(uint32))
    }

    public mutating func pack(_ int32: Int32) throws -> Data {
        return try pack(Int(int32))
    }

    public mutating func pack(_ uint64: UInt64) throws -> Data {
        return try pack(UInt(uint64))
    }

    public mutating func pack(_ int64: Int64) throws -> Data {
        return try pack(Int(int64))
    }

    public mutating func pack(_ uint: UInt) throws -> Data {
        if uint >= UInt(Int64.max) + 1 && uint <= UInt(UInt64.max) {
            // uint64
            var type = UInt8(0xcf)
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var value = UInt64(uint).bigEndian
            self.append(UnsafeBufferPointer(start: &value, count: 1))

            return self
        }

        return try pack(Int(uint))
    }

    public mutating func pack(_ int: Int) throws -> Data {
        switch int {
        case (Int(UInt32.max) + 1)...Int(Int64.max):
            // positive int64
            var type = UInt8(0xd3)
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var value = UInt64(int).bigEndian
            self.append(UnsafeBufferPointer(start: &value, count: 1))
        case (Int(Int32.max) + 1)...Int(UInt32.max):
            // uint32
            var type = UInt8(0xce)
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var value = UInt32(int).bigEndian
            self.append(UnsafeBufferPointer(start: &value, count: 1))
        case (Int(UInt16.max) + 1)...Int(Int32.max):
            // positive int32
            var type = UInt8(0xd2)
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var value = UInt32(int).bigEndian
            self.append(UnsafeBufferPointer(start: &value, count: 1))
        case (Int(Int16.max) + 1)...Int(UInt16.max):
            // uint16
            var type = UInt8(0xcd)
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var value = UInt16(int).bigEndian
            self.append(UnsafeBufferPointer(start: &value, count: 1))
        case (Int(UInt8.max) + 1)...Int(Int16.max):
            // positive int16
            var type = UInt8(0xd1)
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var value = UInt16(int).bigEndian
            self.append(UnsafeBufferPointer(start: &value, count: 1))
        case (Int(Int8.max) + 1)...Int(UInt8.max):
            // uint8
            var type = UInt8(0xcc)
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var value: UInt8 = UInt8(int & 0xff)
            self.append(UnsafeBufferPointer(start: &value, count: 1))
        case 0...Int(Int8.max):
            // positive fixint
            var type: UInt8 = UInt8(int & 0x7f)
            self.append(UnsafeBufferPointer(start: &type, count: 1))
        case -32..<0:
            // negative fixint
            var type: UInt8 = UInt8(int & 0xff)
            self.append(UnsafeBufferPointer(start: &type, count: 1))
        case Int(Int8.min)...(-33):
            // negative int8
            var type = UInt8(0xd0)
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var value: UInt8 = UInt8(int & 0xff)
            self.append(UnsafeBufferPointer(start: &value, count: 1))
        case Int(Int16.min)...(Int(Int8.min) - 1):
            // negative int16
            var type = UInt8(0xd1)
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var value = UInt16(bitPattern: Int16(int)).bigEndian
            self.append(UnsafeBufferPointer(start: &value, count: 1))
        case Int(Int32.min)...(Int(Int16.min) - 1):
            // negative int32
            var type = UInt8(0xd2)
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var value = UInt32(bitPattern: Int32(int)).bigEndian
            self.append(UnsafeBufferPointer(start: &value, count: 1))
        case Int(Int64.min)...(Int(Int32.min) - 1):
            // negative int64
            var type = UInt8(0xd3)
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var value = UInt64(bitPattern: Int64(int)).bigEndian
            self.append(UnsafeBufferPointer(start: &value, count: 1))
        default:
            throw MsgPackError.UnsupportedValue("Int(\(int))")
        }

        return self
    }

    public mutating func pack(_ flt: Float) throws -> Data {
        var type = UInt8(0xca)
        self.append(UnsafeBufferPointer(start: &type, count: 1))
        var value = flt.bitPattern.bigEndian
        self.append(UnsafeBufferPointer(start: &value, count: 1))
        return self
    }

    public mutating func pack(_ dbl: Double) throws -> Data {
        var type = UInt8(0xcb)
        self.append(UnsafeBufferPointer(start: &type, count: 1))
        //var value = CFConvertDoubleHostToSwapped(dbl)
        var value = dbl.bitPattern.bigEndian
        self.append(UnsafeBufferPointer(start: &value, count: 1))
        return self
    }

    public mutating func pack(_ str: String) throws -> Data {
        if str.isEmpty {
            var type: UInt8 = 0xa0
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            return self
        }

        // get UTF8 encoding of string
        guard var strdata = str.data(using: String.Encoding.utf8) else {
            throw MsgPackError.NoUTF8String(str)
        }

        // append string header (depends on string length)
        let len = strdata.count
        if len < 32 {
            var type: UInt8 = 0xa0 + UInt8(len)
            self.append(UnsafeBufferPointer(start: &type, count: 1))
        } else if len < Int(UInt8.max) {
            var type: UInt8 = 0xd9
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var len = UInt8(len)
            self.append(UnsafeBufferPointer(start: &len, count: 1))
        } else if len < Int(UInt16.max) {
            var type: UInt8 = 0xda
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var len = UInt16(len).bigEndian
            self.append(UnsafeBufferPointer(start: &len, count: 1))
        } else if len < Int(UInt32.max) {
            var type: UInt8 = 0xdb
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var len = UInt32(len).bigEndian
            self.append(UnsafeBufferPointer(start: &len, count: 1))
        } else {
            throw MsgPackError.TooMuchData("String contains \(len) bytes")
        }

        self.append(strdata)

        return self
    }

    public mutating func pack(_ data: Data) throws -> Data {
        if data.count < Int(UInt8.max) {
            var type: UInt8 = 0xc4
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var len = UInt8(data.count)
            self.append(UnsafeBufferPointer(start: &len, count: 1))
        } else if data.count < Int(UInt16.max) {
            var type: UInt8 = 0xc5
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var len = UInt16(data.count).bigEndian
            self.append(UnsafeBufferPointer(start: &len, count: 1))
        } else if data.count < Int(UInt32.max) {
            var type: UInt8 = 0xc6
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var len = UInt32(data.count).bigEndian
            self.append(UnsafeBufferPointer(start: &len, count: 1))
        } else {
            throw MsgPackError.TooMuchData("Data contains \(data.count) bytes")
        }

        self.append(data)
        return self
    }

    public mutating func pack(_ array: [Any?]) throws -> Data {
        if array.count < 16 {
            var type: UInt8 = UInt8(0x90 + array.count)
            self.append(UnsafeBufferPointer(start: &type, count: 1))
        } else if array.count < Int(UInt16.max) {
            var type: UInt8 = 0xdc
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var len = UInt16(array.count).bigEndian
            self.append(UnsafeBufferPointer(start: &len, count: 1))
        } else if array.count < Int(UInt32.max) {
            var type: UInt8 = 0xdd
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var len = UInt32(array.count).bigEndian
            self.append(UnsafeBufferPointer(start: &len, count: 1))
        } else {
            throw MsgPackError.TooMuchData("Array contains" +
                                             " \(array.count) bytes")
        }

        for entry in array {
            let _ = try self.pack(entry)
        }

        return self
    }

    public mutating func pack(_ dict: [AnyHashable: Any?]) throws -> Data {
        if dict.count < 16 {
            var type: UInt8 = UInt8(0x80 + dict.count)
            self.append(UnsafeBufferPointer(start: &type, count: 1))
        } else if dict.count < Int(UInt16.max) {
            var type: UInt8 = 0xde
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var len = UInt16(dict.count).bigEndian
            self.append(UnsafeBufferPointer(start: &len, count: 1))
        } else if dict.count < Int(UInt32.max) {
            var type: UInt8 = 0xdf
            self.append(UnsafeBufferPointer(start: &type, count: 1))
            var len = UInt32(dict.count).bigEndian
            self.append(UnsafeBufferPointer(start: &len, count: 1))
        } else {
            throw MsgPackError.TooMuchData("Dictionary contains" +
                                             " \(dict.count) bytes")
        }

        for (key, value) in dict {
            let _ = try self.pack(key)
            let _ = try self.pack(value)
        }

        return self
    }
}

public extension Data {
    public func unpack() throws -> Any? {
        var generator = DataByteGenerator(data: self)
        return try self.unpack(generator: &generator)
    }


    private func unpackString(generator: inout DataByteGenerator,
                              length: Int) throws -> String {
        let data = try generator.nextData(length: length)
        guard let str = String(data: data,
                               encoding: String.Encoding.utf8) else {
            throw MsgPackError.UnsupportedValue("String(\(data))")
        }

        return str
    }

    private func unpackArray(generator: inout DataByteGenerator,
                             length: Int) throws -> [Any?] {
        var array = [Any?]()
        for _ in 0..<length {
            let val = try self.unpack(generator: &generator)
            array.append(val)
        }

        return array
    }

    private func unpackMap(generator: inout DataByteGenerator,
                           length: Int) throws -> [AnyHashable: Any?] {
        var map = [AnyHashable: Any?]()
        for _ in 0..<length {
            let keyobj = try self.unpack(generator: &generator)
            guard let key = keyobj as? AnyHashable else {
                throw MsgPackError.UnsupportedValue("Bad dictionary key" +
                                                      " \(keyobj)")
            }
            let val = try self.unpack(generator: &generator)
            map[key] = val
        }

        return map
    }

    private func unpack(generator: inout DataByteGenerator) throws -> Any? {
        let type = try generator.next()

        switch type {

        // positive fixnum
        case 0x00...0x7f:
            return Int8(type)

        // fixmap
        case 0x80...0x8f:
            let length = Int(type & 0xf)
            return try unpackMap(generator: &generator, length: length)

        // fixarray
        case 0x90...0x9f:
            let length = Int(type & 0xf)
            return try unpackArray(generator: &generator, length: length)

        // negative fixnum
        case 0xe0...0xff:
            let int8 = Int8(Int(type) - 256)
            return int8

        // fixstr
        case 0xa0...0xbf:
            let length = Int(type - 0xa0)
            return try unpackString(generator: &generator, length: length)

        // nil
        case 0xc0:
            return nil

        // false
        case 0xc2:
            return false

        // true
        case 0xc3:
            return true

        // bin8
        case 0xc4:
            let length = Int(try generator.next())
            return try generator.nextData(length: length)

        // bin16
        case 0xc5:
            let length = Int(try generator.next16())
            return try generator.nextData(length: length)

        // bin32
        case 0xc6:
            let length = Int(try generator.next32())
            return try generator.nextData(length: length)

        // float
        case 0xca:
            let uval = try generator.next32()
            return Float(bitPattern: uval)

        // double
        case 0xcb:
            let uval = try generator.next64()
            return Double(bitPattern: uval)

        // uint8
        case 0xcc:
            let val = try generator.next()
            return val

        // uint16
        case 0xcd:
            let hi = UInt16(try generator.next())
            let lo = UInt16(try generator.next())
            return (hi << 8 + lo)

        // uint32
        case 0xce:
            let uval = try generator.next32()
            return uval

        // uint64
        case 0xcf:
            let uval = try generator.next64()
            return uval

        // int8
        case 0xd0:
            let val = try generator.next()
            return Int8(Int(val) - 256)

        // int16
        case 0xd1:
            let hi = UInt16(try generator.next())
            let lo = UInt16(try generator.next())
            return Int16(bitPattern: hi << 8 + lo)

        // int32
        case 0xd2:
            let uval = try generator.next32()
            return Int32(bitPattern: uval)

        // int64
        case 0xd3:
            let uval = try generator.next64()
            return Int64(bitPattern: uval)

        // str8
        case 0xd9:
            let length = Int(try generator.next())
            return try unpackString(generator: &generator, length: length)

        // str16
        case 0xda:
            let length = Int(try generator.next()) << 8 +
                         Int(try generator.next())
            return try unpackString(generator: &generator, length: length)

        // str32
        case 0xdb:
            let length = Int(try generator.next()) << 24 +
                         Int(try generator.next()) << 16 +
                         Int(try generator.next()) << 8 +
                         Int(try generator.next())

            return try unpackString(generator: &generator, length: length)

        // array16
        case 0xdc:
            let len = Int(try generator.next16())
            return try unpackArray(generator: &generator, length: len)

        // array32
        case 0xdd:
            let len = Int(try generator.next32())
            return try unpackArray(generator: &generator, length: len)

        // map16
        case 0xde:
            let len = Int(try generator.next16())
            return try unpackMap(generator: &generator, length: len)

        // map32
        case 0xdf:
            let len = Int(try generator.next32())
            return try unpackMap(generator: &generator, length: len)

        default:
            throw MsgPackError.UnsupportedValue(String(format: "Type(%02x)",
                                                       type))
        }
    }
}
