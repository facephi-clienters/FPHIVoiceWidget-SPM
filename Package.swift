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
        .package(url: "git@github.com:facephi-clienters/SDK-FPHIDesignSystemResources-SPM.git", exact: "2.7.4"),
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
            url: "https://facephicorp.jfrog.io/artifactory/spm-pro-fphi/WIDGET/FPHIVoiceWidget/0.1.6/FPHIVoiceWidget.zip",
            checksum: "ba6cc3ca96de5d36991f85a9ad17635bd4ae895a3448a4c5500c2ab2d52f257c"
        ),
    ]
)
