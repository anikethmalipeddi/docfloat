// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "DocFloat",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "DocFloat", targets: ["DocFloat"])
  ],
  targets: [
    .executableTarget(
      name: "DocFloat",
      path: "Sources/DocFloat"
    ),
    .testTarget(
      name: "DocFloatTests",
      dependencies: ["DocFloat"],
      path: "Tests/DocFloatTests"
    ),
  ]
)
