// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "EleDock",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0")
    ],
    targets: [
        .target(name: "EleDockCore"),
        .executableTarget(
            name: "EleDock",
            dependencies: ["EleDockCore", .product(name: "Sparkle", package: "Sparkle")],
            swiftSettings: [.defaultIsolation(MainActor.self)],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(
            name: "EleDockCoreTests",
            dependencies: ["EleDockCore"],
            swiftSettings: [
                .unsafeFlags(["-plugin-path", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"])
            ]
        ),
    ]
)
