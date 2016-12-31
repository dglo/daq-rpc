class StupidMsgProc: MessageProcessor {
    override func processOne(msg: MethodCall) throws -> Any? {
        return msg.name as Any
    }
}
