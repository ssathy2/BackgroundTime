Pod::Spec.new do |spec|
  spec.name         = "BackgroundTime"
  spec.version      = "1.0.0"
  spec.summary      = "A comprehensive iOS SDK for monitoring and analyzing background task performance"
  
  spec.description  = <<-DESC
    BackgroundTime is an advanced iOS SDK that provides comprehensive monitoring, 
    analytics, and debugging capabilities for background tasks. It features automatic 
    instrumentation via method swizzling, thread-safe data storage using circular 
    buffers, and real-time dashboard integration.
    
    Key Features:
    - Automatic background task instrumentation
    - Thread-safe data collection with circular buffers
    - Real-time performance monitoring
    - Web dashboard integration
    - Memory-efficient storage patterns
    - Comprehensive analytics and reporting
  DESC

  spec.homepage     = "https://github.com/yourusername/BackgroundTime"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "Siddharth Sathyam" => "your.email@example.com" }
  
  spec.ios.deployment_target = "14.0"
  spec.osx.deployment_target = "11.0"
  spec.tvos.deployment_target = "14.0"
  spec.watchos.deployment_target = "7.0"
  spec.visionos.deployment_target = "1.0"
  
  spec.source       = { :git => "https://github.com/yourusername/BackgroundTime.git", :tag => "#{spec.version}" }
  
  spec.source_files = [
    "Sources/BackgroundTime/**/*.swift",
    "BackgroundTime.swift",
    "BackgroundTimeConfiguration.swift", 
    "BackgroundTimeModels.swift",
    "BackgroundTaskDataStore.swift",
    "NetworkManager.swift",
    "BGTaskSchedulerSwizzler.swift",
    "BGTaskSwizzler.swift",
    "CircularBuffer.swift",
    "ThreadSafeAccessManager.swift",
    "BackgroundTimeDashboard.swift",
    "DashboardViewModel.swift"
  ]
  
  spec.exclude_files = "Tests/**/*"
  
  spec.frameworks = [
    "Foundation",
    "BackgroundTasks",
    "UIKit",
    "SwiftUI",
    "Combine"
  ]
  
  spec.requires_arc = true
  spec.swift_versions = ["5.7", "5.8", "5.9"]
  
  spec.pod_target_xcconfig = {
    'SWIFT_VERSION' => '5.9',
    'ENABLE_BITCODE' => 'NO'
  }
  
  # Test specifications
  spec.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.swift'
    test_spec.dependency 'Quick', '~> 7.0'
    test_spec.dependency 'Nimble', '~> 12.0'
  end
  
  # App specifications for demo app
  spec.app_spec 'Demo' do |app_spec|
    app_spec.source_files = 'Demo/**/*.swift'
    app_spec.resources = 'Demo/**/*.{storyboard,xib,xcassets,strings}'
  end
end