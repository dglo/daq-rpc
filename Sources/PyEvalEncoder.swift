import Foundation

let stringQuote: Character = "'"

extension String {
    func contains(_ ch: Character) -> Bool {
        var index = self.startIndex
        while index <= self.endIndex {
            if self[index] == ch {
                return true
            }
            index = self.index(after: index)
        }
        return false
    }
}

typealias PyTuple<Element> = [Element]

class PythonDecoder {
    var buf: String
    var offset: String.Index

    init(_ bytes: [UInt8]) throws {
        if bytes.count == 0 {
            throw I3RPCError.Serialize("Cannot decode an empty string")
        }

        guard let bstr = String(bytes: bytes,
                                encoding: String.Encoding.ascii) else {
            throw I3RPCError.Serialize("Cannot stringify \(bytes.count)" +
                                       " bytes")
        }

        buf = bstr
        offset = buf.startIndex
    }

    func decode() throws -> Any? {
        switch (buf[offset]) {
        case "{":
            offset = buf.index(after: offset)
            let map = try decodeMap();
            if buf[offset] != "}" {
                throw I3RPCError.Serialize("Failed to decode dictionary" +
                                           " (at char \(offset)" +
                                           " in \"\(buf)\"")
            }
            offset = buf.index(after: offset)
            return map as Any
        case "[":
            offset = buf.index(after: offset)
            let list = try decodeList();
            if buf[offset] != "]" {
                throw I3RPCError.Serialize("Failed to decode list" +
                                           " (at char \(offset)" +
                                           " in \"\(buf)\"")
            }
            offset = buf.index(after: offset)
            return list as Any
        case "(":
            offset = buf.index(after: offset)
            let tuple = try decodeTuple();
            if buf[offset] != ")" {
                throw I3RPCError.Serialize("Failed to decode tuple" +
                                           " (at char \(offset)" +
                                           " in \"\(buf)\"")
            }
            offset = buf.index(after: offset)
            return tuple as Any
        case "0"..."9", "-", "+":
            return try decodeNumber()
        case stringQuote:
            offset = buf.index(after: offset)
            let str = try decodeString()
            if buf[offset] != stringQuote {
                throw I3RPCError.Serialize("Failed to decode string" +
                                           " (at char \(offset)" +
                                           " in \"\(buf)\"")
            }
            offset = buf.index(after: offset)
            return str
        case "N":
            let after = buf.index(offset, offsetBy: 4)
            let range = offset..<after
            let none = buf[range]
            if none == "None" {
                offset = after
                return nil as Any?
            }
            fallthrough
        default:
            throw I3RPCError.Serialize("Unrecognized symbol '\(buf[offset])" +
                                       "' (at char \(offset)" +
                                           " in \"\(buf)\"")
        }
    }

    func decodeList() throws -> [Any?] {
        var coll = [Any?]()

        var comma = false
        while true {
            if !comma {
                comma = true
            } else {
                try skipCharacter(",")
            }

            let elem = try decode()
            coll.append(elem)

            if buf[offset] == "]"  {
                break
            }
        }

        return coll
    }

    func decodeMap() throws -> [String: Any?] {
        var map = [String: Any?]()

        var comma = false
        while true {
            if !comma {
                comma = true
            } else {
                try skipCharacter(",")
            }

            if let key = try decode() as? String {
                try skipCharacter(":")
                map[key] = try decode()
            } else {
                throw I3RPCError.Serialize("Key was not a String")
            }

            if offset < buf.endIndex && buf[offset] == "}" {
                break
            }
        }

        return map
    }

    func decodeNumber() throws -> Any {
        var sbuf = ""
        var scanning = true
        var negative = false
        while scanning && offset < buf.endIndex {
            switch buf[offset] {
            case "+":
                 continue
            case "-":
                negative = true
                sbuf.append("-")
            case "0"..."9":
                sbuf.append(buf[offset])
            case ".":
                sbuf.append(buf[offset])
            default:
                scanning = false
            }

            if scanning {
                offset = buf.index(after: offset)
            }
        }

        if sbuf.contains(".") {
            if var val = Double(sbuf) {
                if negative {
                    val = -val
                }

                return val as Any
            }

            throw I3RPCError.Serialize("Bad floating point number" +
                                       "\"\(sbuf)\" (at char #\(offset)" +
                                       " in \"\(buf)\")")
        }

        if negative {
            if let val = Int(sbuf) {
                return val as Any
            }
        } else if let val = UInt(sbuf) {
            return val as Any
        }

        throw I3RPCError.Serialize("Bad integral number \"\(sbuf)\"" +
                                   " (at char #\(offset)" +
                                   " in \"\(buf)\")")
    }

    func decodeString() throws -> Any {
        var str = ""
        while buf[offset] != stringQuote {
            str.append(buf[offset])
            offset = buf.index(after: offset)
            if offset >= buf.endIndex {
                throw I3RPCError.Serialize("Fell off the end of \"\(buf)\"")
            }
        }
        //let obj = str as Any
        //return obj
        return str as Any
    }

    func decodeTuple() throws -> PyTuple<Any?> {
        var tuple = PyTuple<Any?>()

        var comma = false
        while true {
            if !comma {
                comma = true
            } else {
                try skipCharacter(",")
            }

            let elem = try decode()
            tuple.append(elem)

            if buf[offset] == ")"  {
                break
            }
        }

        return tuple
    }

    func isWhitespace(_ ch: Character) -> Bool {
        // ghetto implementation until I figure out how to use CharacterSet?
        return ch == " " || ch == "\t" || ch == "\n" || ch == "\r";
    }

    func skipCharacter(_ ch: Character) throws {
        if (offset >= buf.endIndex || buf[offset] != ch) {
            throw I3RPCError.Serialize("Failed to find \'\(ch)'" +
                                       " (at char \(offset)" +
                                       " in \"\(buf)\"")
        }

        offset = buf.index(after: offset)
        while offset < buf.endIndex && isWhitespace(buf[offset]) {
            offset = buf.index(after: offset)
        }
    }
}

class PyEvalEncoder: Encoder {
    func decode(_ rawbytes: [UInt8]) throws -> Any? {
        let decoder = try PythonDecoder(rawbytes)
        return try decoder.decode()
    }

    func encode(_ object: Any?) throws -> [UInt8] {
        var buf = ""

        do {
            try encode(buffer: &buf, object: object)
        } catch {
            throw error
        }

        return [UInt8] (buf.utf8)
    }

    func encode(buffer: inout String, object: Any?) throws {
        if let value = object {
            if let map = value as? [String: Any?] {
                try encodeDictionary(buffer: &buffer, dictionary: map)
            } else if let tuple = value as? PyTuple<Any> {
                try encodeTuple(buffer: &buffer, tuple: tuple)
            } else if let list = value as? [Any?] {
                try encodeList(buffer: &buffer, list: list)
            } else if let str = value as? String {
                try encodeString(buffer: &buffer, string: str)
            } else if let dbl = value as? Double {
                try encodeNumber(buffer: &buffer, number: dbl)
            } else if let flt = value as? Float {
                let fstr = String(format: "%.8f", flt)
                print("Flt => \(fstr)")
                buffer += fstr
            } else if let uint = value as? UInt {
                buffer += "\(uint)"
            } else if let int = value as? Int {
                buffer += "\(int)"
            } else {
                let vtype = type(of: value)
                throw I3RPCError.Serialize("Cannot encode \(value)<\(vtype)>")
            }
        } else {
            buffer += "None"
        }
    }

    func encodeDictionary(buffer: inout String,
                          dictionary: [String: Any?]) throws {
        buffer += "{"

        var comma = false
        for (key, value) in dictionary {
            if comma {
                buffer += ", "
            } else {
                comma = true
            }

            try encode(buffer: &buffer, object: key as Any?)
            buffer += ": "
            try encode(buffer: &buffer, object: value)
        }

        buffer += "}"
    }

    func encodeList(buffer: inout String, list: [Any?]) throws {
        buffer += "["

        var comma = false
        for value in list {
            if comma {
                buffer += ", "
            } else {
                comma = true
            }

            try encode(buffer: &buffer, object: value)
        }

        buffer += "]"
    }

    func encodeNumber(buffer: inout String, number: Double) throws {
        var dstr = String(format: "%.8f", number)

        var cutoff = dstr.endIndex
        while cutoff != dstr.startIndex &&
                dstr[dstr.index(before: cutoff)] == "0" {
            cutoff = dstr.index(before: cutoff)
        }
        if cutoff != dstr.startIndex &&
             dstr[dstr.index(before: cutoff)] == "." {
            cutoff = dstr.index(before: cutoff)
        }

        if cutoff != dstr.endIndex {
            let rng = cutoff..<dstr.endIndex
            dstr.removeSubrange(rng)
        }

        buffer += dstr
    }

    func encodeString(buffer: inout String, string: String) throws {
        buffer.append(stringQuote)
        buffer += string
        buffer.append(stringQuote)
    }

    func encodeTuple(buffer: inout String, tuple: PyTuple<Any>) throws {
        buffer += "("

        var comma = false
        for value in tuple {
            if comma {
                buffer += ", "
            } else {
                comma = true
            }

            try encode(buffer: &buffer, object: value)
        }

        buffer += ")"
    }
}
