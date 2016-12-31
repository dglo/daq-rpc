class MessageProcessor {
    private var encoder: Encoder
    private var formatter: Formatter

    init(encoder: Encoder, formatter: Formatter) {
        self.encoder = encoder
        self.formatter = formatter
    }

    func add(resolver: Resolver) throws {
        throw I3RPCError.Execute("Unimplemented(add)")
    }

    func bytesToHexString(_ bytes: [UInt8]) -> String {
        return bytes.map{String(format: "%02x", $0)}.joined(separator: "")
    }

    func encodeError(_ errMsg: String) throws -> [UInt8] {
        let error = try formatter.formatError(request: MethodCall.UNKNOWN,
                                              error: errMsg)
        return try encoder.encode(error)
    }

    func getEncoder() -> Encoder {
        return encoder
    }

    func processOne(msg: MethodCall) throws -> Any? {
        throw I3RPCError.Execute("Unimplemented(processOne)")
    }

    func processMessage(msg: [UInt8]) -> [UInt8] {
        var procError = false

        let decoded: Any?
        do {
            decoded = try encoder.decode(msg)
        } catch {
            decoded = nil
            procError = true
        }

        var finalMsg: MethodCall
        do {
            finalMsg = try formatter.extractRequest(decoded)
        } catch {
            finalMsg = MethodCall.UNKNOWN
            procError = true
        }

        var reply: Any?
        if procError {
            let hexStr = bytesToHexString(msg)
            let errMsg = "Cannot decode message \(hexStr)"
            do {
                reply = try formatter.formatError(request: finalMsg,
                                                  error: errMsg)
            } catch {
                // XXX this is the wrong thing to do!
                fatalError("Aborted decode error report")
            }
        } else {
            do {
                let result = try processOne(msg: finalMsg)
                reply = try formatter.formatResult(request: finalMsg,
                                                   result: result)
            } catch {
                do {
                    let errMsg = "Cannot process \(finalMsg): \(error)"
                    reply = try formatter.formatError(request: finalMsg,
                                                      error: errMsg)
                } catch {
                    // XXX this is the wrong thing to do!
                    fatalError("Aborted process error report")
                }
            }
        }

        do {
            return try encoder.encode(reply)
        } catch {
            let errMsg = "Cannot encode reply: \(error)"
            do {
                let errMap = try formatter.formatError(request: finalMsg,
                                                       error: errMsg)
                return try encoder.encode(errMap)
            } catch {
                // XXX this is the wrong thing to do!
                fatalError("Aborted encode")
            }
        }
    }
}
