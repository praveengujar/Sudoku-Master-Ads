# Uncomment the next line to define a global platform for your project
platform :ios, '14.0'

target 'Sudoku Master' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Sudoku Master
  
  # Meta Audience Network (Facebook Ads) - Primary ad network
  pod 'FBAudienceNetwork', '~> 6.15'
  
  # Performance and analytics (optional but recommended)
  pod 'Firebase/Analytics', '~> 10.0'
  pod 'Firebase/Crashlytics', '~> 10.0'
  
  # Promise dependencies for Firebase (if needed for analytics)
  pod 'PromisesObjC', '2.3.1'
  pod 'PromisesSwift', '2.3.1'

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
      
      # Fix PromisesSwift module resolution by adding explicit Swift module search paths
      if target.name == 'PromisesSwift'
        config.build_settings['SWIFT_INCLUDE_PATHS'] ||= []
        config.build_settings['SWIFT_INCLUDE_PATHS'] << '$(PODS_CONFIGURATION_BUILD_DIR)/PromisesObjC'
        config.build_settings['SWIFT_INCLUDE_PATHS'] << '$(PODS_ROOT)/PromisesObjC'
        
        # Ensure FBLPromises module is accessible
        config.build_settings['OTHER_SWIFT_FLAGS'] ||= []
        config.build_settings['OTHER_SWIFT_FLAGS'] << '-Xcc'
        config.build_settings['OTHER_SWIFT_FLAGS'] << '-I$(PODS_CONFIGURATION_BUILD_DIR)/PromisesObjC'
      end
      
    end
  end
end