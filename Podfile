# Uncomment the next line to define a global platform for your project
platform :ios, '14.0'

target 'Sudoku Master' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Sudoku Master
  
  # Google AdMob SDK
  pod 'Google-Mobile-Ads-SDK', '~> 11.0'
  
  # Google User Messaging Platform for GDPR/CCPA compliance
  pod 'GoogleUserMessagingPlatform', '~> 2.1'
  
  # Meta Audience Network (Facebook Ads)
  pod 'FBAudienceNetwork', '~> 6.15'
  
  # TikTok Audience Network (temporarily disabled)
  # pod 'Ads-Global', '~> 5.7'
  
  # Performance and analytics (optional but recommended)
  pod 'Firebase/Analytics', '~> 10.0'
  pod 'Firebase/Crashlytics', '~> 10.0'
  
  # Explicit Promise dependencies to fix module resolution
  pod 'PromisesObjC', '~> 2.1'
  pod 'PromisesSwift', '~> 2.1'

  target 'Sudoku MasterTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'Sudoku MasterUITests' do
    # Pods for testing
  end
end

# Post-install hook to configure build settings for optimal performance
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Optimize for performance
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-O'
      config.build_settings['GCC_OPTIMIZATION_LEVEL'] = 'fast'
      
      # iOS deployment target consistency
      config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
      
      # Fix sandbox issues with FBAudienceNetwork and other frameworks
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      config.build_settings['ENABLE_MODULE_VERIFIER'] = 'NO'
      
      # Fix file permissions for frameworks
      config.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= []
      config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '$(PODS_ROOT)/**'
      
      # Fix module map issues for Promises
      if target.name == 'PromisesSwift'
        config.build_settings['SWIFT_INCLUDE_PATHS'] ||= []
        config.build_settings['SWIFT_INCLUDE_PATHS'] << '$(PODS_ROOT)/PromisesObjC'
        config.build_settings['OTHER_SWIFT_FLAGS'] ||= []
        config.build_settings['OTHER_SWIFT_FLAGS'] << '-Xcc'
        config.build_settings['OTHER_SWIFT_FLAGS'] << '-fmodule-map-file=$(PODS_ROOT)/Target Support Files/PromisesObjC/PromisesObjC.modulemap'
      end
    end
  end
end