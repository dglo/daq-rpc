import Foundation
import XCTest
@testable import daq_rpc

class MsgPackTests: XCTestCase {
    func arrayToHexString(_ data: [UInt8], elide: Bool = true) -> String {
        var buf = ""
        var prev = UInt8(0)
        var hasPrev = false
        var skipped = 0
        for b in data {
            if hasPrev && prev == b {
                skipped += 1
            } else {
                if skipped > 0 {
                    buf.append("*\(skipped)")
                    skipped = 0
                }
                hasPrev = true
                buf.append(String(format: "%02x", b))
            }
            prev = b
        }
        if skipped > 0 {
            buf.append("*\(skipped)")
        }
        return buf
    }

    func dataToHexString(_ data: Data, elide: Bool = true) -> String {
        var buf = ""
        var prev = UInt8(0)
        var hasPrev = false
        var skipped = 0
        for b in data {
            if hasPrev && prev == b {
                skipped += 1
            } else {
                if skipped > 0 {
                    buf.append("*\(skipped+1)")
                    skipped = 0
                }
                hasPrev = true
                buf.append(String(format: "%02x", b))
            }
            prev = b
        }
        if skipped > 0 {
            buf.append("*\(skipped+1)")
        }
        return buf
    }

    func elide(_ str: String) -> String {
        var buf = ""
        var prev = Character("\0")
        var skipped = 0
        for ch in str.characters {
            if prev == ch {
                skipped += 1
            } else {
                if skipped > 0 {
                    buf += "*\(skipped+1)"
                    skipped = 0
                }
                buf.append(ch)
            }
            prev = ch
        }
        if skipped > 0 {
            buf += "*\(skipped+1)"
        }

        return buf
    }

    private func checkString(name: String, source: String, bytes: [UInt8]) {
        var data = Data()
        do {
            let _ = try data.pack(source)
        } catch {
            XCTFail("Cannot pack \(source): \(error)")
            return
        }

        if data.count != bytes.count {
            XCTFail("\(name) String \"\(elide(source))\" should encode to" +
                      " \(bytes.count) bytes, not \(data.count)")
            return
        }

        var idx = 0
        for b in data {
            if bytes[idx] != b {
                XCTFail("Byte #\(idx) should be \(bytes[idx]), not \(b)")
                return
            }
            idx += 1
        }

        let target: String
        do {
            guard let unpacked = try data.unpack() else {
                XCTFail("Could not unpack \(name) data")
                return
            }

            guard let tmpval = unpacked as? String else {
                XCTFail("Could not cast \(name) target to String")
                return
            }

            target = tmpval
        } catch {
            XCTFail("Could not unpack \(name) data: \(error)")
            return
        }

        if target.characters.count != source.characters.count {
            XCTFail("Packed \(name) String unpacked to" +
                      " \(target.characters.count)," +
                      " not \(source.characters.count)")
            return
        }

        if target != source {
            XCTFail("Packed \(name) String unpacked to \(elide(target))," +
                      " not \(elide(source))")
            return
        }
    }

    func testEmptyString() {
        checkString(name: "Empty", source: "", bytes: [0xa0])
    }

    func testTinyString() {
        checkString(name: "Tiny", source: "Hello, world",
                    bytes: [0xac, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x2c, 0x20,
                            0x77, 0x6f, 0x72, 0x6c, 0x64])
    }

    func testShortString() {
        var buf = ""
        var bytes = [UInt8]()

        bytes.append(0xd9)
        bytes.append(UInt8(UInt8.max - 1))

        for _ in 0..<(UInt8.max - 1) {
            buf.append("x")
            bytes.append(0x78)
        }
        checkString(name: "Short", source: buf, bytes: bytes)
    }

    func testMediumString() {
        var buf = ""
        var bytes = [UInt8]()

        bytes.append(0xda)
        let len = UInt16(UInt16.max - 1)
        bytes.append(UInt8((len >> 8) & 0xff))
        bytes.append(UInt8(len & 0xff))

        for _ in 0..<(UInt16.max - 1) {
            buf.append("x")
            bytes.append(0x78)
        }
        checkString(name: "Medium", source: buf, bytes: bytes)
    }

    func testHugeString() {
        var buf = ""
        var bytes = [UInt8]()

        bytes.append(0xdb)

        let len = UInt32(UInt16.max) + 1
        bytes.append(UInt8((len >> 24) & 0xff))
        bytes.append(UInt8((len >> 16) & 0xff))
        bytes.append(UInt8((len >> 8) & 0xff))
        bytes.append(UInt8(len & 0xff))

        for _ in 0..<len {
            buf.append("x")
            bytes.append(0x78)
        }
        checkString(name: "Huge", source: buf, bytes: bytes)
    }

    func checkBool(source: Bool, byte: UInt8) {
        var data = Data()
        do {
            let _ = try data.pack(source)
        } catch {
            XCTFail("Cannot pack \(source): \(error)")
            return
        }

        if data.count != 1 {
            XCTFail("Bool \(source) should encode to 1 byte, not \(data.count)")
            return
        }

        if data[0] != byte {
            XCTFail("Bool \(source) byte \(data[0]) should be \(byte)")
            return
        }

        let target: Bool
        do {
            guard let unpacked = try data.unpack() else {
                XCTFail("Could not unpack Bool \(source) data")
                return
            }

            guard let tmpval = unpacked as? Bool else {
                XCTFail("Could not cast Bool \(source) target")
                return
            }

            target = tmpval
        } catch {
            XCTFail("Could not unpack Bool \(source) data: \(error)")
            return
        }

        if target != source {
            XCTFail("Packed Bool \(source) unpacked to \(target)")
            return
        }
    }

    func testFalse() {
        checkBool(source: false, byte: UInt8(0xc2))
    }

    func testTrue() {
        checkBool(source: true, byte: UInt8(0xc3))
    }

    func testNil() {
        let source: Any? = nil
        var data = Data()
        do {
            let _ = try data.pack(source)
        } catch {
            XCTFail("Cannot pack \(source): \(error)")
            return
        }

        if data.count != 1 {
            XCTFail("Nil should encode to 1 byte, not \(data.count)")
            return
        }

        let byte = UInt8(0xc0)
        if data[0] != byte {
            XCTFail("Nil byte \(data[0]) should be \(byte)")
            return
        }

        do {
            if let unpacked = try data.unpack() {
                XCTFail("Nil data unexpectedly imported as \(unpacked)")
                return
            }
        } catch {
            XCTFail("Could not unpack Nil data: \(error)")
            return
        }
    }

    private func checkUInt8(source: UInt8, bytes: [UInt8]) {
        var data = Data()
        do {
            let _ = try data.pack(source)
        } catch {
            XCTFail("Cannot pack \(source): \(error)")
            return
        }

        if data.count != bytes.count {
            XCTFail("UInt8 \(source) should encode to \(bytes.count) bytes," +
                      " not \(data.count)")
            return
        }

        var idx = 0
        for b in data {
            if UInt8(bytes[idx]) != b {
                XCTFail("UInt8 \(source) byte #\(idx) should be" +
                          " \(bytes[idx]), not \(b)")
                return
            }
            idx += 1
        }

        let target: UInt8
        do {
            guard let unpacked = try data.unpack() else {
                XCTFail("Could not unpack UInt8 \(source) data")
                return
            }

            if let tmpval = unpacked as? UInt8 {
                target = tmpval
            } else if let tmpval = unpacked as? Int8 {
                target = UInt8(tmpval)
            } else {
                XCTFail("Could not cast UInt8 \(source) data")
                return
            }
        } catch {
            XCTFail("Could not unpack UInt8 \(source) data: \(error)")
            return
        }

        if target != source {
            XCTFail("Packed UInt8 \(source) unpacked to \(target)")
            return
        }
    }

    func testUInt8() {
        checkUInt8(source: UInt8(0), bytes: [0])
        checkUInt8(source: UInt8(0x7f), bytes: [0x7f])
        checkUInt8(source: UInt8(0x81), bytes: [0xcc, 0x81])
        checkUInt8(source: UInt8.max, bytes: [0xcc, UInt8.max])
    }

    private func checkInt8(source: Int8, bytes: [UInt8]) {
        var data = Data()
        do {
            let _ = try data.pack(source)
        } catch {
            XCTFail("Cannot pack \(source): \(error)")
            return
        }

        if data.count != bytes.count {
            XCTFail("Int8 \(source) should encode to \(bytes.count) bytes," +
                      " not \(data.count)")
            return
        }

        var idx = 0
        for b in data {
            if bytes[idx] != b {
                XCTFail("Int8 \(source) byte #\(idx) should be" +
                          " \(bytes[idx]), not \(b)")
                return
            }
            idx += 1
        }

        let target: Int8
        do {
            guard let unpacked = try data.unpack() else {
                XCTFail("Could not unpack Int8 \(source) data")
                return
            }

            guard let tmpval = unpacked as? Int8 else {
                XCTFail("Could not cast Int8 \(source) target")
                return
            }

            target = tmpval
        } catch {
            XCTFail("Could not unpack Int8 \(source) data: \(error)")
            return
        }

        if target != source {
            XCTFail("Packed Int8 \(source) unpacked to \(target)")
            return
        }
    }

    func testInt8() {
        checkInt8(source: Int8.min, bytes: [0xd0, 0x80])
        checkInt8(source: Int8.min + 1, bytes: [0xd0, 0x81])
        checkInt8(source: Int8(-33), bytes: [0xd0, 0xdf])
        checkInt8(source: Int8(-32), bytes: [0xe0])
        checkInt8(source: Int8(-1), bytes: [0xff])
        checkInt8(source: Int8(0), bytes: [0])
        checkInt8(source: Int8.max - 1, bytes: [0x7e])
        checkInt8(source: Int8.max, bytes: [0x7f])
    }

    private func checkUInt16(source: UInt16, bytes: [UInt8]) {
        var data = Data()
        do {
            let _ = try data.pack(source)
        } catch {
            XCTFail("Cannot pack \(source): \(error)")
            return
        }

        if data.count != bytes.count {
            XCTFail("UInt16 \(source) should encode to \(bytes.count) bytes," +
                      " not \(data.count)")
            return
        }

        var idx = 0
        for b in data {
            if bytes[idx] != b {
                XCTFail("UInt16 \(source) byte #\(idx) should be" +
                          " \(bytes[idx]), not \(b)")
                return
            }
            idx += 1
        }

        let target: UInt16
        do {
            guard let unpacked = try data.unpack() else {
                XCTFail("Could not unpack UInt16 \(source) data")
                return
            }

            if let tmpval = unpacked as? UInt16 {
                target = tmpval
            } else if let tmpval = unpacked as? Int16 {
                target = UInt16(tmpval)
            } else if let tmpval = unpacked as? UInt8 {
                target = UInt16(tmpval)
            } else if let tmpval = unpacked as? Int8 {
                target = UInt16(tmpval)
            } else {
                XCTFail("Could not cast UInt16 \(source) data")
                return
            }
        } catch {
            XCTFail("Could not unpack UInt16 \(source) data: \(error)")
            return
        }

        if target != source {
            XCTFail("Packed UInt16 \(source) unpacked to \(target)")
            return
        }
    }

    func testUInt16() {
        checkUInt16(source: UInt16(0), bytes: [0])
        checkUInt16(source: UInt16(0x7f), bytes: [0x7f])
        checkUInt16(source: UInt16(0x80), bytes: [0xcc, 0x80])
        checkUInt16(source: UInt16(UInt8.max), bytes: [0xcc, UInt8.max])
        checkUInt16(source: UInt16(UInt8.max) + 1, bytes: [0xd1, 0x01, 0x0])
        checkUInt16(source: UInt16(Int16.max) - 1, bytes: [0xd1, 0x7f, 0xfe])
        checkUInt16(source: UInt16(Int16.max), bytes: [0xd1, 0x7f, 0xff])
        checkUInt16(source: UInt16(Int16.max) + 1, bytes: [0xcd, 0x80, 0x0])
        checkUInt16(source: UInt16.max, bytes: [0xcd, 0xff, 0xff])
    }

    private func checkInt16(source: Int16, bytes: [UInt8]) {
        var data = Data()
        do {
            let _ = try data.pack(source)
        } catch {
            XCTFail("Cannot pack \(source): \(error)")
            return
        }

        if data.count != bytes.count {
            XCTFail("Int16 \(source) should encode to \(bytes.count) bytes," +
                      " not \(data.count)")
            return
        }

        var idx = 0
        for b in data {
            if bytes[idx] != b {
                XCTFail("Int16 \(source) byte #\(idx) should be" +
                          " \(bytes[idx]), not \(b)")
                return
            }
            idx += 1
        }

        let target: Int16
        do {
            guard let unpacked = try data.unpack() else {
                XCTFail("Could not unpack Int16 \(source) data")
                return
            }

            if let tmpval = unpacked as? UInt16 {
                target = Int16(tmpval)
            } else if let tmpval = unpacked as? Int16 {
                target = Int16(tmpval)
            } else if let tmpval = unpacked as? UInt8 {
                target = Int16(tmpval)
            } else if let tmpval = unpacked as? Int8 {
                target = Int16(tmpval)
            } else {
                XCTFail("Could not cast UInt16 \(source) data")
                return
            }
        } catch {
            XCTFail("Could not unpack Int16 \(source) data: \(error)")
            return
        }

        if target != source {
            XCTFail("Packed Int16 \(source) unpacked to \(target)")
            return
        }
    }

    func testInt16() {
        checkInt16(source: Int16.min, bytes: [0xd1, 0x80, 0])
        checkInt16(source: Int16.min + 1, bytes: [0xd1, 0x80, 0x01])
        checkInt16(source: Int16(Int8.min) - 1, bytes: [0xd1, 0xff, 0x7f])
        checkInt16(source: Int16(Int8.min), bytes: [0xd0, 0x80])
        checkInt16(source: Int16(Int8.min + 1), bytes: [0xd0, 0x81])
        checkInt16(source: Int16(-33), bytes: [0xd0, 0xdf])
        checkInt16(source: Int16(-32), bytes: [0xe0])
        checkInt16(source: Int16(-1), bytes: [0xff])
        checkInt16(source: Int16(0), bytes: [0])
        checkInt16(source: Int16(Int8.max - 1), bytes: [0x7e])
        checkInt16(source: Int16(Int8.max), bytes: [0x7f])
        checkInt16(source: Int16(Int8.max) + 1, bytes: [0xcc, 0x80])
        checkInt16(source: Int16.max - 1, bytes: [0xd1, 0x7f, 0xfe])
        checkInt16(source: Int16.max, bytes: [0xd1, 0x7f, 0xff])
    }

    private func checkUInt32(source: UInt32, bytes: [UInt8]) {
        var data = Data()
        do {
            let _ = try data.pack(source)
        } catch {
            XCTFail("Cannot pack \(source): \(error)")
            return
        }

        if data.count != bytes.count {
            XCTFail("UInt32 \(source) should encode to \(bytes.count) bytes," +
                      " not \(data.count)")
            return
        }

        var idx = 0
        for b in data {
            if bytes[idx] != b {
                XCTFail("UInt32 \(source) byte #\(idx) should be" +
                          " \(bytes[idx]), not \(b)")
                return
            }
            idx += 1
        }

        let target: UInt32
        do {
            guard let unpacked = try data.unpack() else {
                XCTFail("Could not unpack UInt32 \(source) data")
                return
            }

            if let tmpval = unpacked as? UInt32 {
                target = tmpval
            } else if let tmpval = unpacked as? Int32 {
                target = UInt32(tmpval)
            } else if let tmpval = unpacked as? UInt16 {
                target = UInt32(tmpval)
            } else if let tmpval = unpacked as? Int16 {
                target = UInt32(tmpval)
            } else if let tmpval = unpacked as? UInt8 {
                target = UInt32(tmpval)
            } else if let tmpval = unpacked as? Int8 {
                target = UInt32(tmpval)
            } else {
                XCTFail("Could not cast UInt32 \(source) data")
                return
            }
        } catch {
            XCTFail("Could not unpack UInt32 \(source) data: \(error)")
            return
        }

        if target != source {
            XCTFail("Packed UInt32 \(source) unpacked to \(target)")
            return
        }
    }

    func testUInt32() {
        checkUInt32(source: UInt32(0), bytes: [0])
        checkUInt32(source: UInt32(0x7f), bytes: [0x7f])
        checkUInt32(source: UInt32(0x80), bytes: [0xcc, 0x80])
        checkUInt32(source: UInt32(UInt8.max), bytes: [0xcc, UInt8.max])
        checkUInt32(source: UInt32(UInt8.max) + 1, bytes: [0xd1, 0x01, 0x0])
        checkUInt32(source: UInt32(Int16.max) - 1, bytes: [0xd1, 0x7f, 0xfe])
        checkUInt32(source: UInt32(Int16.max), bytes: [0xd1, 0x7f, 0xff])
        checkUInt32(source: UInt32(Int16.max) + 1, bytes: [0xcd, 0x80, 0x0])
        checkUInt32(source: UInt32.max - 1,
                    bytes: [0xce, 0xff, 0xff, 0xff, 0xfe])
        checkUInt32(source: UInt32.max,
                    bytes: [0xce, 0xff, 0xff, 0xff, 0xff])
    }

    private func checkInt32(source: Int32, bytes: [UInt8]) {
        var data = Data()
        do {
            let _ = try data.pack(source)
        } catch {
            XCTFail("Cannot pack Int32 \(source): \(error)")
            return
        }

        if data.count != bytes.count {
            XCTFail("Int32 \(source) should encode to \(bytes.count) bytes," +
                      " not \(data.count)")
            return
        }

        var idx = 0
        for b in data {
            if bytes[idx] != b {
                XCTFail("Int32 \(source) byte #\(idx) should be" +
                          " \(bytes[idx]), not \(b)")
                return
            }
            idx += 1
        }

        let target: Int32
        do {
            guard let unpacked = try data.unpack() else {
                XCTFail("Could not unpack Int32 \(source) data")
                return
            }

            if let tmpval = unpacked as? UInt32 {
                target = Int32(bitPattern: tmpval)
            } else if let tmpval = unpacked as? Int32 {
                target = tmpval
            } else if let tmpval = unpacked as? UInt16 {
                target = Int32(tmpval)
            } else if let tmpval = unpacked as? Int16 {
                target = Int32(tmpval)
            } else if let tmpval = unpacked as? UInt8 {
                target = Int32(tmpval)
            } else if let tmpval = unpacked as? Int8 {
                target = Int32(tmpval)
            } else {
                XCTFail("Could not cast UInt32 \(source) data")
                return
            }
        } catch {
            XCTFail("Could not unpack Int32 \(source) data: \(error)")
            return
        }

        if target != source {
            XCTFail("Packed Int32 \(source) unpacked to \(target)")
            return
        }
    }

    func testInt32() {
        checkInt32(source: Int32.min,
                   bytes: [0xd2, 0x80, 0, 0, 0])
        checkInt32(source: Int32.min + 1,
                   bytes: [0xd2, 0x80, 0, 0, 0x01])
        checkInt32(source: Int32(Int16.min) - 1,
                   bytes: [0xd2, 0xff, 0xff, 0x7f, 0xff])
        checkInt32(source: Int32(Int16.min), bytes: [0xd1, 0x80, 0])
        checkInt32(source: Int32(Int16.min) + 1, bytes: [0xd1, 0x80, 0x01])
        checkInt32(source: Int32(Int8.min) - 1, bytes: [0xd1, 0xff, 0x7f])
        checkInt32(source: Int32(Int8.min), bytes: [0xd0, 0x80])
        checkInt32(source: Int32(Int8.min + 1), bytes: [0xd0, 0x81])
        checkInt32(source: Int32(-33), bytes: [0xd0, 0xdf])
        checkInt32(source: Int32(-32), bytes: [0xe0])
        checkInt32(source: Int32(-1), bytes: [0xff])
        checkInt32(source: Int32(0), bytes: [0])
        checkInt32(source: Int32(Int8.max - 1), bytes: [0x7e])
        checkInt32(source: Int32(Int8.max), bytes: [0x7f])
        checkInt32(source: Int32(Int8.max) + 1, bytes: [0xcc, 0x80])
        checkInt32(source: Int32(Int16.max) - 1, bytes: [0xd1, 0x7f, 0xfe])
        checkInt32(source: Int32(Int16.max), bytes: [0xd1, 0x7f, 0xff])
        checkInt32(source: Int32(Int16.max) + 1, bytes: [0xcd, 0x80, 0])
        checkInt32(source: Int32.max - 1,
                   bytes: [0xd2, 0x7f, 0xff, 0xff, 0xfe])
        checkInt32(source: Int32.max,
                   bytes: [0xd2, 0x7f, 0xff, 0xff, 0xff])
    }

    private func checkUInt64(source: UInt64, bytes: [UInt8]) {
        var data = Data()
        do {
            let _ = try data.pack(source)
        } catch {
            XCTFail("Cannot pack \(source): \(error)")
            return
        }

        if data.count != bytes.count {
            XCTFail("UInt64 \(source) should encode to \(bytes.count) bytes," +
                      " not \(data.count)")
            return
        }

        var idx = 0
        for b in data {
            if bytes[idx] != b {
                XCTFail("UInt64 \(source) byte #\(idx) should be" +
                          " \(bytes[idx]), not \(b)")
                return
            }
            idx += 1
        }

        let target: UInt64
        do {
            guard let unpacked = try data.unpack() else {
                XCTFail("Could not unpack UInt64 \(source) data")
                return
            }

            if let tmpval = unpacked as? UInt64 {
                target = tmpval
            } else if let tmpval = unpacked as? Int64 {
                target = UInt64(tmpval)
            } else if let tmpval = unpacked as? UInt32 {
                target = UInt64(tmpval)
            } else if let tmpval = unpacked as? Int32 {
                target = UInt64(tmpval)
            } else if let tmpval = unpacked as? UInt16 {
                target = UInt64(tmpval)
            } else if let tmpval = unpacked as? Int16 {
                target = UInt64(tmpval)
            } else if let tmpval = unpacked as? UInt8 {
                target = UInt64(tmpval)
            } else if let tmpval = unpacked as? Int8 {
                target = UInt64(tmpval)
            } else {
                XCTFail("Could not cast UInt64 \(source) data")
                return
            }
        } catch {
            XCTFail("Could not unpack UInt64 \(source) data: \(error)")
            return
        }

        if target != source {
            XCTFail("Packed UInt64 \(source) unpacked to \(target)")
            return
        }
    }

    func testUInt64() {
        checkUInt64(source: UInt64(0), bytes: [0])
        checkUInt64(source: UInt64(0x7f), bytes: [0x7f])
        checkUInt64(source: UInt64(0x80), bytes: [0xcc, 0x80])
        checkUInt64(source: UInt64(UInt8.max), bytes: [0xcc, UInt8.max])
        checkUInt64(source: UInt64(UInt8.max) + 1, bytes: [0xd1, 0x01, 0x0])
        checkUInt64(source: UInt64(Int16.max) - 1, bytes: [0xd1, 0x7f, 0xfe])
        checkUInt64(source: UInt64(Int16.max), bytes: [0xd1, 0x7f, 0xff])
        checkUInt64(source: UInt64(Int16.max) + 1, bytes: [0xcd, 0x80, 0x0])
        checkUInt64(source: UInt64(Int32.max) - 1,
                    bytes: [0xd2, 0x7f, 0xff, 0xff, 0xfe])
        checkUInt64(source: UInt64(Int32.max),
                    bytes: [0xd2, 0x7f, 0xff, 0xff, 0xff])
        checkUInt64(source: UInt64(Int32.max) + 1,
                    bytes: [0xce, 0x80, 0x0, 0x0, 0x0])
        checkUInt64(source: UInt64.max - 1,
                    bytes: [0xcf, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                            0xfe])
        checkUInt64(source: UInt64.max,
                    bytes: [0xcf, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                            0xff])
    }

    private func checkInt64(source: Int64, bytes: [UInt8]) {
        var data = Data()
        do {
            let _ = try data.pack(source)
        } catch {
            XCTFail("Cannot pack \(source): \(error)")
            return
        }

        if data.count != bytes.count {
            XCTFail("Int64 \(source) should encode to \(bytes.count) bytes," +
                      " not \(data.count)")
            return
        }

        var idx = 0
        for b in data {
            if bytes[idx] != b {
                XCTFail("Int64 \(source) byte #\(idx) should be" +
                          " \(bytes[idx]), not \(b)")
                return
            }
            idx += 1
        }

        let target: Int64
        do {
            guard let unpacked = try data.unpack() else {
                XCTFail("Could not unpack Int64 \(source) data")
                return
            }

            if let tmpval = unpacked as? UInt64 {
                target = Int64(bitPattern: tmpval)
            } else if let tmpval = unpacked as? Int64 {
                target = tmpval
            } else if let tmpval = unpacked as? UInt32 {
                target = Int64(tmpval)
            } else if let tmpval = unpacked as? Int32 {
                target = Int64(tmpval)
            } else if let tmpval = unpacked as? UInt16 {
                target = Int64(tmpval)
            } else if let tmpval = unpacked as? Int16 {
                target = Int64(tmpval)
            } else if let tmpval = unpacked as? UInt8 {
                target = Int64(tmpval)
            } else if let tmpval = unpacked as? Int8 {
                target = Int64(tmpval)
            } else {
                XCTFail("Could not cast Int64 \(source) data")
                return
            }
        } catch {
            XCTFail("Could not unpack Int64 \(source) data: \(error)")
            return
        }

        if target != source {
            XCTFail("Packed Int64 \(source) unpacked to \(target)")
            return
        }
    }

    func testInt64() {
        checkInt64(source: Int64.min,
                   bytes: [0xd3, 0x80, 0, 0, 0, 0, 0, 0, 0])
        checkInt64(source: Int64.min + 1,
                   bytes: [0xd3, 0x80, 0, 0, 0, 0, 0, 0, 0x01])
        checkInt64(source: Int64(Int32.min) - 1,
                   bytes: [0xd3, 0xff, 0xff, 0xff, 0xff, 0x7f, 0xff, 0xff,
                           0xff])
        checkInt64(source: Int64(Int32.min),
                   bytes: [0xd2, 0x80, 0, 0, 0])
        checkInt64(source: Int64(Int32.min) + 1,
                   bytes: [0xd2, 0x80, 0, 0, 0x01])
        checkInt64(source: Int64(Int16.min) - 1,
                   bytes: [0xd2, 0xff, 0xff, 0x7f, 0xff])
        checkInt64(source: Int64(Int16.min), bytes: [0xd1, 0x80, 0])
        checkInt64(source: Int64(Int16.min) + 1, bytes: [0xd1, 0x80, 0x01])
        checkInt64(source: Int64(Int8.min) - 1, bytes: [0xd1, 0xff, 0x7f])
        checkInt64(source: Int64(Int8.min), bytes: [0xd0, 0x80])
        checkInt64(source: Int64(Int8.min + 1), bytes: [0xd0, 0x81])
        checkInt64(source: Int64(-33), bytes: [0xd0, 0xdf])
        checkInt64(source: Int64(-32), bytes: [0xe0])
        checkInt64(source: Int64(-1), bytes: [0xff])
        checkInt64(source: Int64(0), bytes: [0])
        checkInt64(source: Int64(Int8.max - 1), bytes: [0x7e])
        checkInt64(source: Int64(Int8.max), bytes: [0x7f])
        checkInt64(source: Int64(Int8.max) + 1, bytes: [0xcc, 0x80])
        checkInt64(source: Int64(Int16.max) - 1, bytes: [0xd1, 0x7f, 0xfe])
        checkInt64(source: Int64(Int16.max), bytes: [0xd1, 0x7f, 0xff])
        checkInt64(source: Int64(Int16.max) + 1, bytes: [0xcd, 0x80, 0])
        checkInt64(source: Int64(Int32.max) - 1,
                   bytes: [0xd2, 0x7f, 0xff, 0xff, 0xfe])
        checkInt64(source: Int64(Int32.max),
                   bytes: [0xd2, 0x7f, 0xff, 0xff, 0xff])
        checkInt64(source: Int64(Int32.max) + 1,
                   bytes: [0xce, 0x80, 0, 0, 0])
        checkInt64(source: Int64.max - 1,
                   bytes: [0xd3, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                           0xfe])
        checkInt64(source: Int64.max,
                   bytes: [0xd3, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                           0xff])
    }

    private func checkFloat(source: Float, bytes: [UInt8]) {
        var data = Data()
        do {
            let _ = try data.pack(source)
        } catch {
            XCTFail("Cannot pack \(source): \(error)")
            return
        }

        if data.count != bytes.count {
            XCTFail("Float \(source) should encode to \(bytes.count) bytes," +
                      " not \(data.count)")
            return
        }

        var idx = 0
        var failed = false
        for b in data {
            if bytes[idx] != b {
                let expHex = String(format: "%02x", bytes[idx])
                let gotHex = String(format: "%02x", b)
                XCTFail("Float \(source) byte #\(idx) should be" +
                          " \(expHex), not \(gotHex)")
                failed = true
            }
            idx += 1
        }
        if failed { return }

        let target: Float
        do {
            guard let unpacked = try data.unpack() else {
                XCTFail("Could not unpack Float \(source) data")
                return
            }

            if let tmpval = unpacked as? Float {
                target = tmpval
            } else {
                XCTFail("Could not cast Float \(source) data")
                return
            }
        } catch {
            XCTFail("Could not unpack Float \(source) data: \(error)")
            return
        }

        if target != source {
            XCTFail("Packed Float \(source) unpacked to \(target)")
            return
        }
    }

    func testFloat() {
        checkFloat(source: Float(0.0), bytes: [0xca, 0, 0, 0, 0])
        checkFloat(source: Float(1.0), bytes: [0xca, 0x3f, 0x80, 0, 0])
        checkFloat(source: Float(-123.456),
                   bytes: [0xca, 0xc2, 0xf6, 0xe9, 0x79])
        checkFloat(source: Float(9876.54321),
                   bytes: [0xca, 0x46, 0x1a, 0x52, 0x2c])
    }

    private func checkDouble(source: Double, bytes: [UInt8]) {
        var data = Data()
        do {
            let _ = try data.pack(source)
        } catch {
            XCTFail("Cannot pack \(source): \(error)")
            return
        }

        if data.count != bytes.count {
            XCTFail("Double \(source) should encode to \(bytes.count) bytes," +
                      " not \(data.count)")
            return
        }

        var idx = 0
        var failed = false
        for b in data {
            if bytes[idx] != b {
                let expHex = String(format: "%02x", bytes[idx])
                let gotHex = String(format: "%02x", b)
                XCTFail("Double \(source) byte #\(idx) should be" +
                          " \(expHex), not \(gotHex)")
                failed = true
            }
            idx += 1
        }
        if failed { return }

        let target: Double
        do {
            guard let unpacked = try data.unpack() else {
                XCTFail("Could not unpack Double \(source) data")
                return
            }

            if let tmpval = unpacked as? Double {
                target = tmpval
            } else {
                XCTFail("Could not cast Double \(source) data")
                return
            }
        } catch {
            XCTFail("Could not unpack Double \(source) data: \(error)")
            return
        }

        if target != source {
            XCTFail("Packed Double \(source) unpacked to \(target)")
            return
        }
    }

    func testDouble() {
        checkDouble(source: Double(0.0),
                    bytes: [0xcb, 0, 0, 0, 0, 0, 0, 0, 0])
        checkDouble(source: Double(1.0),
                    bytes: [0xcb, 0x3f, 0xf0, 0, 0, 0, 0, 0, 0])
        checkDouble(source: Double(-123.456),
                    bytes: [0xcb, 0xc0, 0x5e, 0xdd, 0x2f, 0x1a, 0x9f, 0xbe,
                            0x77])
        checkDouble(source: Double(9876.54321),
                    bytes: [0xcb, 0x40, 0xc3, 0x4a, 0x45, 0x87, 0xe7, 0xc0,
                            0x6e])
    }

    private func checkData(source: Data, bytes: [UInt8]) {
        var data = Data()
        do {
            let _ = try data.pack(source)
        } catch {
            XCTFail("Cannot pack \(source): \(error)")
            return
        }

        if data.count != bytes.count {
            XCTFail("Data \(source) should encode to \(bytes.count) bytes," +
                      " not \(data.count)")
            return
        }

        var idx = 0
        var failed = false
        for b in data {
            if bytes[idx] != b {
                let expHex = String(format: "%02x", bytes[idx])
                let gotHex = String(format: "%02x", b)
                XCTFail("Data \(source) byte #\(idx) should be" +
                          " \(expHex), not \(gotHex)")
                failed = true
            }
            idx += 1
        }
        if failed { return }

        let target: Data
        do {
            guard let unpacked = try data.unpack() else {
                XCTFail("Could not unpack Double \(source) data")
                return
            }

            if let tmpval = unpacked as? Data {
                target = tmpval
            } else {
                XCTFail("Could not cast Data \(source) data")
                return
            }
        } catch {
            XCTFail("Could not unpack Data \(source) data: \(error)")
            return
        }

        if target != source {
            XCTFail("Packed Data \(source) unpacked to \(target)")
            return
        }
    }

    func testShortBinary() {
        let bytes: [UInt8] = [0xc4, 0x4, 0x12, 0x34, 0x56, 0x78]
        checkData(source: Data(bytes: bytes[2..<bytes.count]), bytes: bytes)
    }

    func testMediumBinary() {
        var bytes = [UInt8]()

        bytes.append(0xc5)
        let len = UInt16(UInt16.max - 1)
        bytes.append(UInt8((len >> 8) & 0xff))
        bytes.append(UInt8(len & 0xff))

        for _ in 0..<len {
            bytes.append(0x78)
        }
        checkData(source: Data(bytes: bytes[3..<bytes.count]), bytes: bytes)
    }

    func testLongBinary() {
        var bytes = [UInt8]()

        bytes.append(0xc6)

        let len = UInt32(UInt16.max) + 1
        bytes.append(UInt8((len >> 24) & 0xff))
        bytes.append(UInt8((len >> 16) & 0xff))
        bytes.append(UInt8((len >> 8) & 0xff))
        bytes.append(UInt8(len & 0xff))

        for _ in 0..<len {
            bytes.append(0x78)
        }
        checkData(source: Data(bytes[5..<bytes.count]), bytes: bytes)
    }

    private func compareMaps<T1, T2>(source: [AnyHashable: T1],
                                     target: [AnyHashable: T2],
                                     compare: (_: AnyHashable, _: T1,
                                               _: [AnyHashable: T2]) -> Bool)
    {
        if target.count != source.count {
            XCTFail("Packed Map unpacked to \(source.count) elements," +
                      " not \(target.count)")
            return
        }

        for (skey, sobj) in source {
            if !compare(skey, sobj, target) {
                return
            }
        }
    }

    private func compareMapsObjObj(source: [AnyHashable: Any],
                                   target: [AnyHashable: Any]) {
        compareMaps(source: source, target: target) {
            (skey: AnyHashable, sval: Any,
             target: [AnyHashable: Any]) -> Bool in
            guard let tval = target[skey] else {
                XCTFail("Target Map does not contain expected key \(skey)")
                return false
            }


            return compareObjects(source: sval, target: tval)
        }
    }

    private func compareMapsOptOpt(source: [AnyHashable: Any?],
                                   target: [AnyHashable: Any?]) {
        compareMaps(source: source, target: target) {
            (skey: AnyHashable, sobj: Any?,
             target: [AnyHashable: Any?]) -> Bool in

            guard let tobj = target[skey] else {
                XCTFail("Target Map does not contain expected key \(skey)")
                return false
            }

            guard let sval = sobj else {
                if let _ = tobj {
                    XCTFail("Source \(skey) value is nil, target value is" +
                              " \(tobj)")
                    return false
                }

                // both values are nil
                return true
            }

            guard let tval = tobj else {
                XCTFail("Failed to unwrap target \(skey) value \(tobj)")
                return false
            }

            return compareObjects(source: sval, target: tval)
        }
    }

    private func convertAnyToInt(_ val: Any) throws -> Int {
        if let vint = val as? Int {
            return vint
        } else if let vint = val as? Int8 {
            return Int(vint)
        } else if let vint = val as? Int16 {
            return Int(vint)
        } else if let vint = val as? Int32 {
            return Int(vint)
        } else if let vint = val as? Int64 {
            return Int(vint)
        } else if let vint = val as? UInt8 {
            return Int(vint)
        } else if let vint = val as? UInt16 {
            return Int(vint)
        } else if let vint = val as? UInt32 {
            return Int(vint)
        } else if let vint = val as? UInt64 {
            return Int(vint)
        }

        throw MsgPackError.UnsupportedValue("Cannot convert \(val) to Int")
    }

    private func compareObjects(source: Any, target: Any) -> Bool {
        if let sdbl = source as? Double {
            if let tdbl = target as? Double {
                if sdbl != tdbl {
                    XCTFail("Source \(source) != target \(target)")
                    return false
                }
            } else {
                let badType: Any.Type = type(of: target)
                XCTFail("Target \(target) is \(badType) not Double(\(source))")
                return false
            }
        } else if let sflt = source as? Float {
            if let tflt = target as? Float {
                if sflt != tflt {
                    XCTFail("Source \(source) != target \(target)")
                    return false
                }
            } else {
                let badType: Any.Type = type(of: target)
                XCTFail("Target \(target) is \(badType) not Float(\(source))")
                return false
            }
        } else if let sint = source as? Int {
            do {
                let tint = try convertAnyToInt(target)
                if sint != tint {
                    XCTFail("Source \(source) != target \(target)")
                    return false
                }
            } catch {
                XCTFail("Cannot convert \(target) to Int: \(error)")
            }
        } else if let sbool = source as? Bool {
            if let tbool = target as? Bool {
                if sbool != tbool {
                    XCTFail("Source \(source) != target \(target)")
                    return false
                }
            } else {
                let badType: Any.Type = type(of: target)
                XCTFail("Target \(target) is \(badType) not Bool(\(source))")
                return false
            }
        } else if let sarray = source as? [Any?] {
            if let tarray = target as? [Any?] {
                if sarray.count != tarray.count {
                    XCTFail("Source length \(sarray.count) != target" +
                              " length \(tarray.count)")
                    return false
                }
            } else {
                let badType: Any.Type = type(of: target)
                XCTFail("Target \(target) is \(badType) not Array(\(source))")
                return false
            }
/*
        } else if let xset = source as? Set {
            fatalError("Not checking Set")
        } else if let map = source as? [AnyHashable: Any?] {
            fatalError("Not checking Dictionary")
*/
        } else if let sstr = source as? String {
            if let tstr = target as? String {
                if sstr != tstr {
                    XCTFail("Source \(source) != target \(target)")
                    return false
                }
            } else {
                let badType: Any.Type = type(of: target)
                XCTFail("Target \(target) is \(badType) not String(\(source))")
                return false
            }
        } else {
            XCTFail("Unknown type for source \(source)")
        }

        return true
    }

    private func checkArray(source: [Any?], bytes: [UInt8]) {
        var data = Data()
        do {
            let _ = try data.pack(source)
        } catch {
            XCTFail("Cannot pack \(source): \(error)")
            return
        }

        if data.count != bytes.count {
            XCTFail("Array \(source) should encode to \(bytes.count) bytes," +
                      " not \(data.count)")
            return
        }

        var idx = 0
        var failed = false
        for b in data {
            if bytes[idx] != b {
                let expHex = String(format: "%02x", bytes[idx])
                let gotHex = String(format: "%02x", b)
                XCTFail("Array byte #\(idx) should be" +
                          " \(expHex), not \(gotHex)")
                failed = true
            }
            idx += 1
        }
        if failed { return }

        let target: [Any?]
        do {
            guard let unpacked = try data.unpack() else {
                XCTFail("Could not unpack Array \(source) data")
                return
            }

            if let tmpval = unpacked as? [Any?] {
                target = tmpval
            } else {
                XCTFail("Could not cast Array \(source) data")
                return
            }
        } catch {
            XCTFail("Could not unpack Array \(source) data: \(error)")
            return
        }

        if target.count != source.count {
            XCTFail("Packed Array unpacked to \(source.count) elements," +
                      " not \(target.count)")
            return
        }

        for i in 0..<source.count {
            if let tentry = target[i] {
                guard let sentry = source[i] else {
                    XCTFail("Target Array element#\(i) is \(tentry), not nil")
                    return
                }

                if !compareObjects(source: sentry, target: tentry) {
                    return
                }
            } else if let sentry = source[i] {
                XCTFail("Target Array element#\(i) is nil, not \(sentry)")
                return
            }
        }
    }

    func testSmallArray() {
        let smallArray = ["a", "b", "c"]

        checkArray(source: smallArray,
                   bytes: [0x93, 0xa1, 0x61, 0xa1, 0x62, 0xa1, 0x63])
    }

    func testMediumArray() {
        var source = [String]()
        var bytes = [UInt8]()

        bytes.append(0xdc)
        let len = UInt16(UInt16.max - 1)
        bytes.append(UInt8((len >> 8) & 0xff))
        bytes.append(UInt8(len & 0xff))

        let charA = Int(("a" as UnicodeScalar).value)
        for i in 0..<Int(len) {
            let val = i % 26
            var buf = ""
            buf.append(Character(UnicodeScalar(charA + val)!))
            source.append(buf)
            bytes.append(0xa1)
            bytes.append(UInt8(charA + val))
        }

        checkArray(source: source, bytes: bytes)
    }

    func testLongArray() {
        var source = [String]()
        var bytes = [UInt8]()

        bytes.append(0xdd)

        let len = UInt32(UInt16.max) + 1
        bytes.append(UInt8((len >> 24) & 0xff))
        bytes.append(UInt8((len >> 16) & 0xff))
        bytes.append(UInt8((len >> 8) & 0xff))
        bytes.append(UInt8(len & 0xff))

        let charA = Int(("a" as UnicodeScalar).value)
        for i in 0..<Int(len) {
            let val = i % 26
            var buf = ""
            buf.append(Character(UnicodeScalar(charA + val)!))
            source.append(buf)
            bytes.append(0xa1)
            bytes.append(UInt8(charA + val))
        }

        checkArray(source: source, bytes: bytes)
    }

    private func checkMapByte(exp: UInt8, got: UInt8, idx: Int) -> Bool {
        if exp == got {
            return true
        }

        let expHex = String(format: "%02x", exp)
        let gotHex = String(format: "%02x", got)
        XCTFail("Map byte #\(idx) should be \(expHex), not \(gotHex)")
        return false
    }

    private func checkMap(source: [AnyHashable: Any?], elements: [[UInt8]]) {
        var data = Data()
        do {
            let _ = try data.pack(source)
        } catch {
            XCTFail("Cannot pack \(source): \(error)")
            return
        }

        var byteCount = 1
        for elem in elements {
            byteCount += elem.count
        }

        if data.count != byteCount {
            XCTFail("Map \(source) should encode to \(byteCount) bytes," +
                      " not \(data.count)")
            return
        }

        var curElem = -1
        var elemIdx = 0
        var failed = false
        for idx in 0..<data.count {
            let got = data[idx]
            let expByte: UInt8
            if idx == 0 {
                expByte = UInt8(0x80 + source.count)
            } else {
                if elemIdx == 0 || (curElem >= 0 &&
                                    elemIdx == elements[curElem].count) {
                    curElem = -1
                    elemIdx = 0
                    for i in 0..<source.count {
                        if elements[i][0] == got {
                            if curElem >= 0 {
                                let b0 = String(format: "%02x", got)
                                XCTFail("Map \(source) contains multiple" +
                                        " elements with byte 0 == \(b0)")
                                return
                            }
                            curElem = i
                        }
                    }
                    if curElem < 0 {
                        let b0 = String(format: "%02x", got)
                        XCTFail("Map \(source) does not contain an element" +
                                        " with byte 0 == \(b0)")
                        return
                    }
                }
                expByte = elements[curElem][elemIdx]
            }
            failed = failed || checkMapByte(exp: expByte, got: got, idx: idx)

            if idx > 0 { elemIdx += 1}
        }
        if failed { return }

        let target: [AnyHashable: Any?]
        do {
            guard let unpacked = try data.unpack() else {
                XCTFail("Could not unpack Map \(source) data")
                return
            }

            if let tmpval = unpacked as? [AnyHashable: Any?] {
                target = tmpval
            } else {
                XCTFail("Could not cast Map \(source)")
                return
            }
        } catch {
            XCTFail("Could not unpack Map \(source) data: \(error)")
            return
        }

        if target.count != source.count {
            XCTFail("Packed Map unpacked to \(source.count) elements," +
                      " not \(target.count)")
            return
        }

        for (skey, sobj) in source {
            guard let tobj = target[skey] else {
                XCTFail("Target Map does not contain expected key \(skey)")
                return
            }

            guard let sval = sobj else {
                XCTFail("Failed to unwrap source value \(sobj)")
                return
            }

            guard let tval = tobj else {
                XCTFail("Failed to unwrap target value \(tobj)")
                return
            }

            if !compareObjects(source: sval, target: tval) {
                return
            }
        }
    }

    func testSmallMap() {
        let smallMap: [AnyHashable: Any] = ["a": 1,
                                            "bb": 2.22222,
                                            "ccc": "three",
                                            "dddd": Character("a"),
        ]

        checkMap(source: smallMap,
                 elements: [
                            [0xa1, 0x61, 0x01],
                            [0xa2, 0x62, 0x62, 0xcb, 0x40, 0x01, 0xc7, 0x1b,
                             0x47, 0x84, 0x23, 0x10],
                            [0xa3, 0x63, 0x63, 0x63, 0xa5, 0x74, 0x68, 0x72,
                             0x65, 0x65],
                            [0xa4, 0x64, 0x64, 0x64, 0x64, 0xa1, 0x61],
                            ])
    }

    func testIntDict() {
        let dict: [AnyHashable: Int] = [Int8(123): 456, UInt8(135): 246,
                                        UInt8(147): 369]

        var data = Data()
        do {
            let anydict = dict
            let _ = try data.pack(anydict)
        } catch {
            XCTFail("Cannot pack [Int: Int]: \(error)")
            return
        }

        let unpacked: Any?
        do {
            unpacked = try data.unpack()
        } catch {
            XCTFail("Cannot unpack [Int: Int]: \(error)")
            return
        }

        if let tmpmap = unpacked as? [AnyHashable: Any] {
            compareMapsObjObj(source: dict, target: tmpmap)
        } else {
            XCTFail("Could not cast \(unpacked)")
            return
        }
    }

    func testStringDict() {
        let dict = ["a": "alligator", "b": "buffalo"]

        var data = Data()
        do {
            let _ = try data.pack(dict)
        } catch {
            XCTFail("Cannot pack [String: Any]: \(error)")
            return
        }

        let unpacked: Any?
        do {
            unpacked = try data.unpack()
        } catch {
            XCTFail("Cannot unpack [String: Any]: \(error)")
            return
        }

        if let tmpmap = unpacked as? [String: Any] {
            compareMapsObjObj(source: dict, target: tmpmap)
        } else {
            XCTFail("Could not cast \(unpacked)")
            return
        }
    }

    func testStringMixedDict() {
        let dict: [String: Any?] = ["a": "alligator", "b": nil, "c": 3.14]

        var data = Data()
        do {
            let _ = try data.pack(dict)
        } catch {
            XCTFail("Cannot pack [String: Any?]: \(error)")
            return
        }

        let unpacked: Any?
        do {
            unpacked = try data.unpack()
        } catch {
            XCTFail("Cannot unpack [String: Any?]: \(error)")
            return
        }

        if let tmpmap = unpacked as? [String: Any?] {
            compareMapsOptOpt(source: dict, target: tmpmap)
        } else {
            XCTFail("Could not cast \(unpacked)")
            return
        }
    }

    static var allTests : [(String, (MsgPackTests) -> () throws -> Void)] {
        return [
            ("testEmptyString", testEmptyString),
            ("testTinyString", testTinyString),
            ("testShortString", testShortString),
            ("testMediumString", testMediumString),
            ("testHugeString", testHugeString),
            ("testFalse", testFalse),
            ("testTrue", testTrue),
            ("testNil", testNil),
            ("testUInt8", testUInt8),
            ("testInt8", testInt8),
            ("testUInt16", testUInt16),
            ("testInt16", testInt16),
            ("testUInt32", testUInt32),
            ("testInt32", testInt32),
            ("testUInt64", testUInt64),
            ("testInt64", testInt64),
            ("testFloat", testFloat),
            ("testDouble", testDouble),
            ("testShortBinary", testShortBinary),
            ("testMediumBinary", testMediumBinary),
            ("testLongBinary", testLongBinary),
            ("testSmallArray", testSmallArray),
            ("testMediumArray", testMediumArray),
            ("testLongArray", testLongArray),
            ("testSmallMap", testSmallMap),
            ("testIntDict", testIntDict),
            ("testStringDict", testStringDict),
            ("testStringMixedDict", testStringMixedDict),
        ]
    }
}
