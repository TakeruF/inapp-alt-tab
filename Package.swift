// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "InAppAltTab",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "InAppAltTab", targets: ["InAppAltTab"])],
    targets: [
        .target(name: "WindowCycle"),
        .executableTarget(name: "InAppAltTab", dependencies: ["WindowCycle"],
                          swiftSettings: [.defaultIsolation(MainActor.self),
                                          .enableUpcomingFeature("NonisolatedNonsendingByDefault")]),
        .testTarget(name: "WindowCycleTests", dependencies: ["WindowCycle"])
    ]
)
