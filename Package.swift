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
        .package(url: "git@github.com:facephi-clienters/FPHILicenseManager-SPM.git", exact: "0.5.6"),
        .package(url: "git@github.com:facephi-clienters/SDK-FPHIDesignSystemResources-SPM.git", exact: "1.0.0"),
    ],
    targets: [
        .plugin(
            name: "CopyResources",
            capability: .command(
                intent: .custom(verb: "copy-local-kmp-resources",
                                description: "Copy local KMP Resources for SPM"),
                permissions: [
                    .writeToPackageDirectory(reason: "Adds generated resources.")
                ]
            )
        ),
        .target(
            name: "FPHIVoiceWidget-SPM",
            dependencies: [
                "FPHIVoiceWidget",
                .product(name: "FPHIDesignSystemResources", package: "SDK-FPHIDesignSystemResources-SPM"),
                "FPHILicenseManager-SPM",
            ],
            resources: [.copy("compose/cocoapods/compose-resources")]
        ),
        .binaryTarget(
            name: "FPHIVoiceWidget",
            url: "https://facephicorp.jfrog.io/artifactory/spm-dev-fphi/WIDGET/FPHIVoiceWidget/0.1.1/FPHIVoiceWidget.zip",
            checksum: "57245e861bbf8e7cbc481d86d7673e7be1ff96d03d561fea2df65b74249a8322"
        ),
    ]
)
