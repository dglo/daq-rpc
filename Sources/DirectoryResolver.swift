import Foundation

class DirectoryResolver: Resolver {
    private var directory: Directory

    init(_ directory: Directory) {
        self.directory = directory
    }

    func execute(methodName: String, parameters: [Any?]) -> Resolution {
        switch methodName {
        case "celebrate_birthday":
            fallthrough
        case "celebrateBirthday":
            if parameters.count != 2 {
                return .Failed(error: "Expected 2 parameters, not" +
                                      " \(parameters.count)")
            }

            guard let first = parameters[0] as! String? else {
                return .Failed(error: "First celebrateBirthday() parameter" +
                                      " (\(parameters[0])) is not a String")
            }

            guard let last = parameters[1] as! String? else {
                return .Failed(error: "Second celebrateBirthday() parameter" +
                                      " (\(parameters[1])) is not a String")
            }

            let result = directory.celebrateBirthday(firstName: first,
                                                     lastName: last)
            return .Result(result)
        case "find":
            if parameters.count < 2 || parameters.count > 3 {
                return .Failed(error: "Expected 2 or 3 parameters, not" +
                                      " \(parameters.count)")
            }

            guard let first = parameters[0] as! String? else {
                return .Failed(error: "First find() parameter" +
                                      " (\(parameters[0])) is not a String")
            }

            guard let last = parameters[1] as! String? else {
                return .Failed(error: "Second find() parameter" +
                                      " (\(parameters[1])) is not a String")
            }

            if parameters.count == 3 {
                guard let delayObj = parameters[2] else {
                    return .Failed(error: "Third find() parameter" +
                                          " (\(parameters[2])) cannot be nil")
                }

                let delaySeconds: Int
                if let delayInt = delayObj as? Int {
                    delaySeconds = delayInt
                } else if let delayInt8 = delayObj as? Int8 {
                    delaySeconds = Int(delayInt8)
                } else {
                    return .Failed(error: "Third find() parameter" +
                                          " (\(parameters[2])) is not an Int")
                }

                let delayUSec = UInt32(1000 * delaySeconds)
                usleep(delayUSec)
            }

            if let result = directory.find(firstName: first, lastName: last) {
                return .Result(result.dictionary)
            }

            return .NilResult
        case "huge_reply":
            fallthrough
        case "hugeReply":
            fallthrough
        case "getHugeReply":
            if parameters.count != 0 {
                return .Failed(error: "Expected no parameters, got" +
                                      " \(parameters.count)")
            }

            let result = directory.hugeReply()
            return .Result(result)
        default:
            break
        }

        return .UnknownMethod
    }
}
