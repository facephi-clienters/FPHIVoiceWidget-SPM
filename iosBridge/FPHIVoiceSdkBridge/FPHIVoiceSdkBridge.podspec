Pod::Spec.new do |spec|
    spec.name             = 'FPHIVoiceSdkBridge'
    spec.version          = '0.1.1'
    spec.summary          = 'Objective-C compatible bridge for the Facephi Voice SDK.'
    spec.description      = <<-DESC
        Lightweight Swift bridge used by the KMP Voice Widget to access
        VoiceSDK recording, speech detection, quality check and WAV generation
        without depending on the native Voice ID UI component.
    DESC
    spec.homepage         = 'https://github.com/facephi/voice-widget-kmp'
    spec.license          = { :type => 'UNLICENSED', :text => 'Internal use only' }
    spec.authors          = { 'Facephi' => 'mobile@facephi.com' }
    spec.source           = { :path => '.' }
    spec.ios.deployment_target = '13.0'
    spec.swift_versions   = ['5.9']
    spec.static_framework = true

    spec.source_files     = 'Sources/FPHIVoiceSdkBridge/**/*.{swift}'
    spec.resource_bundles = {
        'FPHIVoiceSdkBridgeResources' => ['Sources/FPHIVoiceSdkBridge/Resources/VoiceSDKResources']
    }
    spec.frameworks       = ['AVFoundation', 'Foundation']
    spec.dependency 'FPHIVoiceSDK', '~> 5.3.2'
    spec.pod_target_xcconfig = {
        'GENERATE_APP_INTENTS_METADATA' => 'NO'
    }
end
