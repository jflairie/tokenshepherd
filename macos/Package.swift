// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TokenShepherd",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TokenShepherd",
            path: "Sources/TokenShepherd",
            resources: [
                .copy("../../Resources/Info.plist")
            ]
        )
    ]
)
