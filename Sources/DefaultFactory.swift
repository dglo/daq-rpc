public class DefaultFactory
{
    public class var encoder: Encoder {
        return MsgPackEncoder()
    }

    public class var formatter: Formatter {
        return JSONRPCFormatter()
    }

    public class func transport(msgproc: MessageProcessor) -> Transport {
        return SocketTransport(msgproc: msgproc)
    }
}
