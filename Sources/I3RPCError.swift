enum I3RPCError: Error {
case Decode(_: String)
case Format(_: String)
case Execute(_: String)
case Serialize(_: String)
case Transport(_: String)
}
