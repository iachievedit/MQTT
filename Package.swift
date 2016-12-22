import PackageDescription

let package = Package(
    name: "MQTT",
    dependencies:[
      .Package(url:"https://github.com/VeniceX/TCPSSL", majorVersion:0, minor:9),
      .Package(url:"https://github.com/iachievedit/swiftlog", majorVersion:1, minor:1)
    ]
)
