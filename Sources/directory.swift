import Foundation

enum DirectoryError: Error {
    case Yuck(_: String)
}

class DirectoryEntry : CustomDebugStringConvertible {
    var firstName: String
    var lastName: String
    private (set) var age: Int

    init(firstName: String, lastName: String, age: Int)
    {
        self.firstName = firstName
        self.lastName = lastName
        self.age = age
    }

    func celebrateBirthday() -> Int {
        age += 1
        return age
    }

    var debugDescription: String {
        return "DirectoryEntry[\(firstName)/\(lastName) #\(age)]"
    }

    var delayedAge: Int {
        get {
            sleep(10)
            return age
        }
    }

    var dictionary: Dictionary<String, Any> {
        var dict = [String: Any]()
        dict["firstName"] = firstName as Any
        dict["lastName"] = lastName as Any
        // this causes an abort
        //dict["triplet"] = triplet as Any
        dict["age"] = age as Any
        return dict
    }

    func illegal() throws -> Int {
        throw DirectoryError.Yuck("FakeError")
    }

    var triplet: (String, String, Int) {
        return (firstName, lastName, age)
    }
}

class Directory: CustomDebugStringConvertible {
    private var list: [DirectoryEntry] = []

    var debugDescription: String {
        return String(format: "Directory*%d", list.count)
    }

    func add(firstName: String, lastName: String, age: Int) {
        list.append(DirectoryEntry(firstName: firstName, lastName: lastName,
                                   age: age))
    }

    func celebrateBirthday(firstName: String, lastName: String) -> Int {
        guard let entry = find(firstName: firstName, lastName: lastName) else {
            return Int.min
        }

        return entry.celebrateBirthday()
    }

    func find(firstName: String, lastName: String) -> DirectoryEntry? {
        for entry in list {
            if entry.firstName == firstName && entry.lastName == lastName {
                return entry
            }
        }

        return nil
    }

    func hugeReply() -> [Any] {
        var reply: [Any] = []
        for i in 1...1000 {
            let entry: Any = [
                "number": i,
                "alphabet": "abcdefghijklmnopqrstuvwxyz",
                "ALPHABET": "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
                "nested": [["a": 1, "b": 2], ["z": -1, "y": -2]],
            ]
            reply.append(entry)
        }
        return reply
    }
}
