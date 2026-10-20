// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenToolbelt",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "OpenToolbeltCore", targets: ["OpenToolbeltCore"]),
        .executable(name: "opentoolbelt", targets: ["opentoolbelt"]),
    ],
    targets: [
        .target(name: "OpenToolbeltCore"),
        .executableTarget(name: "opentoolbelt", dependencies: ["OpenToolbeltCore"]),
        .executableTarget(name: "OpenToolbeltApp", dependencies: ["OpenToolbeltCore"], resources: [.copy("Resources/AgentIcons")]),
        .testTarget(name: "OpenToolbeltCoreTests", dependencies: ["OpenToolbeltCore"]),
    ]
)
