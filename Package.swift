// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "MoaIMF",
  defaultLocalization: "en",
  platforms: [.macOS(.v13)],
  products: [
    .library(name: "MoaIMFCore", targets: ["MoaIMFCore"]),
    .library(name: "MoaIMFUI", targets: ["MoaIMFUI"]),
    .executable(name: "MoaIMF", targets: ["MoaIMFApp"]),
  ],
  targets: [
    .target(name: "MoaIMFCore"),
    .target(
      name: "MoaIMFUI",
      dependencies: ["MoaIMFCore"],
      resources: [.process("Resources")]
    ),
    .executableTarget(name: "MoaIMFApp", dependencies: ["MoaIMFCore", "MoaIMFUI"]),
    .testTarget(name: "MoaIMFCoreTests", dependencies: ["MoaIMFCore"]),
    .testTarget(name: "MoaIMFUITests", dependencies: ["MoaIMFUI", "MoaIMFCore"]),
  ],
  swiftLanguageModes: [.v6]
)
