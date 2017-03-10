Pod::Spec.new do |s|

  s.name         = "IDZSwiftCommonCrypto"
  s.version      = "0.9.1"
  s.summary      = "A wrapper for Apple's Common Crypto library written in Swift."

  s.homepage     = "https://github.com/iosdevzone/IDZSwiftCommonCrypto"
  s.license      = "MIT"
  s.author             = { "iOSDevZone" => "idz@iosdeveloperzone.com" }
  s.social_media_url   = "http://twitter.com/iOSDevZone"
 
  s.osx.deployment_target = '10.11'
  s.ios.deployment_target = '9.0'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '2.0'

  s.source       = { :git => "https://github.com/iosdevzone/IDZSwiftCommonCrypto.git", :tag => s.version.to_s }

  #
  # Create the dummy CommonCrypto.framework structures
  #
  s.prepare_command = <<-CMD
  touch prepare_command.txt
  echo 'Running prepare_command'
  pwd
  echo Running GenerateCommonCryptoModule
  # This was needed to ensure the correct Swift interpreter was 
  # used in Xcode 8. Leaving it here, commented out, in case similar 
  # issues occur when migrating to Swift 4.0.
  #TC="--toolchain com.apple.dt.toolchain.Swift_2_3"
  SWIFT="xcrun $TC swift"
  $SWIFT ./GenerateCommonCryptoModule.swift macosx .
  $SWIFT ./GenerateCommonCryptoModule.swift iphonesimulator .
  $SWIFT ./GenerateCommonCryptoModule.swift iphoneos .
  $SWIFT ./GenerateCommonCryptoModule.swift appletvsimulator .
  $SWIFT ./GenerateCommonCryptoModule.swift appletvos .
  $SWIFT ./GenerateCommonCryptoModule.swift watchsimulator .
  $SWIFT ./GenerateCommonCryptoModule.swift watchos .

CMD

  s.source_files  = "IDZSwiftCommonCrypto"

  # Stop CocoaPods from deleting dummy frameworks
  s.preserve_paths = "Frameworks"

  # Make sure we can find the dummy frameworks
  s.xcconfig = { 
  "SWIFT_VERSION" => "3.0",
  "SWIFT_INCLUDE_PATHS" => "${PODS_ROOT}/IDZSwiftCommonCrypto/Frameworks/$(PLATFORM_NAME)",
  "FRAMEWORK_SEARCH_PATHS" => "${PODS_ROOT}/IDZSwiftCommonCrypto/Frameworks/$(PLATFORM_NAME)"
  }

end
