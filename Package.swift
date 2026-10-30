// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "KnoTime",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "KnoTime", targets: ["KnoTime"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")],
    targets: [
        .target(name: "TimeCore"),
        .executableTarget(name: "KnoTime", dependencies: ["TimeCore", .product(name: "Sparkle", package: "Sparkle")],
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "TimeCoreTests", dependencies: ["TimeCore"])
    ], swiftLanguageModes: [.v5])
