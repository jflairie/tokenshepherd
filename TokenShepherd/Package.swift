// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TokenShepherd",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "TokenShepherd",
            path: "TokenShepherd",
            exclude: ["Resources/Assets.xcassets", "Info.plist", "TokenShepherd.entitlements"],
            sources: [
                "App/TokenShepherdApp.swift",
                "App/AppDelegate.swift",
                "Views/FloatingWidget.swift",
                "Views/CompactView.swift",
                "Views/ExpandedView.swift",
                "Models/UsageData.swift",
                "Models/QuotaResponse.swift",
                "Services/DataService.swift",
                "Services/FileWatcher.swift",
                "Services/QuotaAPI.swift",
                "Services/KeychainService.swift"
            ]
        )
    ]
)
