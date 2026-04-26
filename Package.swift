// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "XMRMenuCalc",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "XMRMenuCalc", targets: ["XMRMenuCalc"]),
    ],
    targets: [
        .executableTarget(
            name: "XMRMenuCalc",
            path: "XMRMenuCalc",
            exclude: ["Info.plist", "Assets.xcassets", "xmr_logo.png"]
        ),
    ]
)
