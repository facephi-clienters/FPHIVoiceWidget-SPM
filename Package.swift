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
        .package(url: "git@github.com:facephi-clienters/SDK-FPHIDesignSystemResources-SPM.git", exact: "2.7.5"),
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
            url: "https://facephicorp.jfrog.io/artifactory/spm-pro-fphi/WIDGET/FPHIVoiceWidget/0.1.7/FPHIVoiceWidget.zip",
            checksum: "5f28d5e98c319a5bf366ff155dcee7af667ec1fdcd712c1ed8cf446a0c2b44ea"
        ),
    ]
)
