// swift-tools-version: 5.9
//
// NOTE: This Package.swift is provided for dependency resolution reference.
// The recommended workflow is to create an Xcode macOS App project:
//
// 1. Open Xcode → File → New → Project → macOS → App (SwiftUI, Swift)
// 2. Name it "ConfluenceToFlare", set deployment target to macOS 14.0
// 3. File → Add Package Dependencies → https://github.com/scinfu/SwiftSoup.git (2.6.0+)
// 4. Drag all .swift files from the ConfluenceToFlare/ subdirectories into the project
// 5. Add Resources/release_note_template.htm to the project target
// 6. Replace entitlements with ConfluenceToFlare.entitlements
// 7. Build and run
//
import PackageDescription

let package = Package(
    name: "ConfluenceToFlare",
    platforms: [
        .macOS(.v14),
        .iOS(.v13),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "ConfluenceToFlare",
            dependencies: ["SwiftSoup"],
            path: "ConfluenceToFlare",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "ConfluenceToFlareTests",
            dependencies: ["ConfluenceToFlare"],
            path: "ConfluenceToFlareTests"
        ),
    ]
)
