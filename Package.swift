// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "ClaudePocketChecker", platforms: [.macOS(.v14)], products: [.executable(name: "ClaudePocketChecker", targets: ["ClaudePocketChecker"])], targets: [.target(name: "MeterCore"), .executableTarget(name: "ClaudePocketChecker", dependencies: ["MeterCore"]), .testTarget(name: "MeterCoreTests", dependencies: ["MeterCore"])])
