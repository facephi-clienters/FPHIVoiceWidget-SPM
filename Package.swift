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
        .library(
            name: "FPHIVoiceWidgetResources",
            targets: ["FPHIVoiceWidgetResources-SPM"],
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/facephi-clienters/FPHILicenseManager-SPM.git", exact: "0.5.7"),
        .package(url: "https://github.com/facephi-clienters/SDK-FPHIDesignSystemResources-SPM.git", exact: "2.8.5"),
        .package(url: "https://github.com/facephi-clienters/VoiceSDK-SPM.git", exact: "5.3.2"),
    ],
    targets: [
        .target(
            name: "FPHIVoiceWidget-SPM",
            dependencies: [
                "FPHIVoiceWidget",
                "FPHIVoiceSdkBridge",
                "FPHIVoiceWidgetResources-SPM",
                .product(name: "FPHIDesignSystemResources", package: "SDK-FPHIDesignSystemResources-SPM"),
                "FPHILicenseManager-SPM",
            ]
        ),
        .target(
            name: "FPHIVoiceWidgetResources-SPM",
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
            url: "https://facephicorp.jfrog.io/artifactory/spm-pro-fphi/WIDGET/FPHIVoiceWidget/0.2.3/FPHIVoiceWidget.zip",
            checksum: "127d9d8777b2331263af9ac8480262f4b2c54120b3b9277a68675be660111776"
        ),
    ]
)
