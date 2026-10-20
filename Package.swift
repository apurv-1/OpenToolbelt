// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenSkills",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OpenSkillsCore", targets: ["OpenSkillsCore"]),
        .executable(name: "openskills", targets: ["openskills"]),
    ],
    targets: [
        .target(name: "OpenSkillsCore"),
        .executableTarget(name: "openskills", dependencies: ["OpenSkillsCore"]),
        .testTarget(name: "OpenSkillsCoreTests", dependencies: ["OpenSkillsCore"]),
    ]
)
