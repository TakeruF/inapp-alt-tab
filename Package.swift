// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "InAppAltTab",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "InAppAltTab", targets: ["InAppAltTab"])],
    targets: [
        .target(name: "WindowCycle"),
        .target(name: "AppLocalization", resources: [.process("Resources")]),
        .executableTarget(name: "InAppAltTab", dependencies: ["WindowCycle", "AppLocalization"],
                          swiftSettings: [.defaultIsolation(MainActor.self),
                                          .enableUpcomingFeature("NonisolatedNonsendingByDefault")]),
        .testTarget(name: "WindowCycleTests", dependencies: ["WindowCycle"]),
        .testTarget(name: "AppLocalizationTests", dependencies: ["AppLocalization"])
    ]
)
