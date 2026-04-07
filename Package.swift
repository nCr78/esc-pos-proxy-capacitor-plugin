// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EscPosProxyCapacitorPlugin",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "EscPosProxyCapacitorPlugin",
            targets: ["ESCPOSProxyPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0")
    ],
    targets: [
        .target(
            name: "ESCPOSProxyPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/ESCPOSProxyPlugin"),
        .testTarget(
            name: "ESCPOSProxyPluginTests",
            dependencies: ["ESCPOSProxyPlugin"],
            path: "ios/Tests/ESCPOSProxyPluginTests")
    ]
)