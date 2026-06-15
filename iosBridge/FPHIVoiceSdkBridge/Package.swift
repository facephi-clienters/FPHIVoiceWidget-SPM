// swift-tools-version: 5.9

import PackageDescription

// Test-only manifest for support code. The published widget package owns the
// runtime FPHIVoiceSdkBridge target and declares VoiceSDK resources there.
let package = Package(
    name: "FPHIVoiceSdkBridge",
    platforms: [.iOS(.v13)],
    targets: [
        .target(
            name: "FPHIVoiceSdkBridgeSupport",
            path: "Sources/FPHIVoiceSdkBridge",
            exclude: [
                "FPHIVoiceSdkBridge.swift",
                "Resources"
            ]
        ),
        .testTarget(
            name: "FPHIVoiceSdkBridgeSupportTests",
            dependencies: ["FPHIVoiceSdkBridgeSupport"],
            path: "Tests/FPHIVoiceSdkBridgeSupportTests"
        )
    ]
)
