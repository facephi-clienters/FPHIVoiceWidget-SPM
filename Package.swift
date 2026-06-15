// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FPHIVoiceWidget-SPM",
    defaultLocalization: "es",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "FPHIVoiceWidget-SPM",
            targets: ["FPHIVoiceWidget-SPM", "FPHIVoiceWidget"],
        ),
    ],
    dependencies: [
        .package(url: "git@github.com:facephi-clienters/FPHILicenseManager-SPM.git", exact: "0.5.7"),
        .package(url: "git@github.com:facephi-clienters/SDK-FPHIDesignSystemResources-SPM.git", exact: "1.0.0"),
        .package(url: "git@github.com:facephi-clienters/VoiceSDK-SPM.git", exact: "5.3.2"),
    ],
    targets: [
        .target(
            name: "FPHIVoiceWidget-SPM",
            dependencies: [
                "FPHIVoiceWidget",
                "FPHIVoiceSdkBridge",
                .product(name: "FPHIDesignSystemResources", package: "SDK-FPHIDesignSystemResources-SPM"),
                "FPHILicenseManager-SPM",
            ],
            resources: [.copy("compose/cocoapods/compose-resources")]
        ),
        .target(
            name: "FPHIVoiceSdkBridge",
            dependencies: [
                .product(name: "VoiceSDK-SPM", package: "VoiceSDK-SPM"),
            ],
            path: "iosBridge/FPHIVoiceSdkBridge/Sources/FPHIVoiceSdkBridge",
            resources: [.copy("Resources/VoiceSDKResources")]
        ),
        .binaryTarget(
            name: "FPHIVoiceWidget",
            url: "https://facephicorp.jfrog.io/artifactory/spm-pro-fphi/WIDGET/FPHIVoiceWidget/0.1.4/FPHIVoiceWidget.zip",
            checksum: "6785e5785280f27c55c5e707e8ff677f8168edf0dc4aa0848fe1412c6c74edb5"
        ),
    ]
)
