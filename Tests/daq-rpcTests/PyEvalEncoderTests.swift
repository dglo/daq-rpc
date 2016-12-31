import XCTest
@testable import daq_rpc

class PyEvalEncoderTests: XCTestCase {
    func checkString(str: String, map: [String: Any]) {
        let encoder = PyEvalEncoder()

        let bytes = [UInt8] (str.utf8)

        var obj: Any
        do {
            if let tmpObj = try encoder.decode(bytes) {
                obj = tmpObj
            } else {
                XCTFail("Could not decode \"\(str)\"")
                return
            }
        } catch {
            XCTFail("Cannot decode \"\(str)\": \(error)")
            return
        }
        XCTAssertNotNil(obj, "Decode returned nil")
        //XCTAssertEqualObjects(obj, map, "Bad decoded object")
print("Decoded \"\(str)\" to \(obj)")

        var encoded: [UInt8]
        do {
            encoded = try encoder.encode(obj)
        } catch {
            XCTFail("Cannot encode \"\(obj)\": \(error)")
            return
        }
        XCTAssertNotNil(encoded, "Decode returned nil")
        XCTAssertEqual(encoded.count, bytes.count, "Bad encoded length")

        guard let encStr = String(bytes: encoded,
                                  encoding: String.Encoding.ascii) else {
            XCTFail("Cannot stringify \(encoded.count) bytes")
            return
        }
        XCTAssertEqual(encStr.utf8.count, str.utf8.count,
                       "Bad encoded string length")
print("Encoded \(obj) to \(encStr)#\(encoded.count)<=>#\(bytes.count)")
    }

    func testSimple() {
        var map = [String: Any]()
        map["one"] = 1
        map["two"] = "too"

        let oneChar: Character = "3"
        map["three"] = oneChar
        map["negMillion"] = -1000000
        map["zeroPtOnes"] = 0.11111111
        map["list"] = [1, 2, 3]

        var tuple = PyTuple<Any>()
        tuple.append("a")
        tuple.append(2)
        tuple.append(3.14159265)
        map["tuple"] = tuple

        let simple = "{'negMillion': -1000000, 'three': '3', 'two': 'too', 'one': 1, 'zeroPtOnes': 0.11111111, 'list': [1, 2, 3], 'tuple': ('a', 2, 3.14159265)}"
        checkString(str: simple, map: map)
    }

    static var allTests : [(String, (PyEvalEncoderTests) -> () throws -> Void)] {
        return [
            ("testSimple", testSimple),
        ]
    }
}
