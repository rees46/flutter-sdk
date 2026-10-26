// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "rees46_sdk",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "rees46-sdk", targets: ["rees46_sdk"])
    ],
    dependencies: [
        // Keep in step with the dependency in ../rees46_sdk.podspec.
        .package(url: "https://github.com/rees46/ios-sdk.git", exact: "3.36.1")
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
