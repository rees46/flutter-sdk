// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "rees46_sdk",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "rees46-sdk", targets: ["rees46_sdk"])
    ],
    dependencies: [
        // Keep in step with the dependency in ../rees46_sdk.podspec. Until the iOS SDK's next release
        // this is its unreleased commit with the full notification history (status, channel, campaign id,
        // statistics); the podspec stays on 3.40.0, a pod cannot name a commit.
        .package(url: "https://github.com/rees46/ios-sdk.git", revision: "40d32d1ce26cb5e964a209f492c36a0406687562")
    ],
    targets: [
        .target(
            name: "rees46_sdk",
            dependencies: [
                .product(name: "REES46", package: "ios-sdk")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
