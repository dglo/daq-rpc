import PackageDescription

let package = Package(
    name: "daq-rpc",
    dependencies: [
      .Package(url: "../i3msgpack", majorVersion: 1)
    ]
)
