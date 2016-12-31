class DefaultFactory
{
    class var encoder: Encoder {
        return MsgPackEncoder()
    }

    class var formatter: Formatter {
        return JSONRPCFormatter()
    }

    class func transport(msgproc: MessageProcessor) -> Transport {
        return SocketTransport(msgproc: msgproc)
    }
}
