import PackageDescription

let package = Package(
    name: "daq-rpc",
    dependencies: [
      .Package(url: "git@github.com:dglo/i3msgpack.git", majorVersion: 0)
    ]
)
