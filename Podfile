# Uncomment the next line to define a global platform for your project
platform :ios, '14.0'

target 'Sudoku Master' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Sudoku Master
  
  # Meta Audience Network (Facebook Ads) - ONLY ad network
  pod 'FBAudienceNetwork', '~> 6.15'
  

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
      
      # Additional sandbox and permission fixes
      config.build_settings['ENABLE_HARDENED_RUNTIME'] = 'NO'
      config.build_settings['OTHER_LDFLAGS'] ||= []
      config.build_settings['OTHER_LDFLAGS'] << '-ObjC'
      
      # Fix file permissions for frameworks
      config.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= []
      config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '$(PODS_ROOT)/**'
      
      
    end
  end
end