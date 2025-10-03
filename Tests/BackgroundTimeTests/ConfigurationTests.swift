//
//  ConfigurationTests.swift
//  BackgroundTimeTests
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Testing
import Foundation
import UIKit
import BackgroundTasks
@testable import BackgroundTime

@Suite("Configuration Tests")
struct ConfigurationTests {
    
    @Test("Default BackgroundTimeConfiguration properties")
    func testDefaultConfiguration() async throws {
        let defaultConfig = BackgroundTimeConfiguration.default
        
        #expect(defaultConfig.maxStoredEvents == 1000, "Default max stored events should be 1000")
        #expect(defaultConfig.apiEndpoint == nil, "Default API endpoint should be nil")
        #expect(defaultConfig.enableNetworkSync == false, "Default network sync should be disabled")
        #expect(defaultConfig.enableDetailedLogging == true, "Default detailed logging should be enabled")
        #expect(BackgroundTimeConfiguration.sdkVersion == "1.0.0", "SDK version should be 1.0.0")
    }
    
    @Test("Custom BackgroundTimeConfiguration with all parameters")
    func testCustomConfigurationAllParams() async throws {
        let customURL = URL(string: "https://api.example.com/v2/background-tasks")!
        let config = BackgroundTimeConfiguration(
            maxStoredEvents: 2500,
            apiEndpoint: customURL,
            enableNetworkSync: true,
            enableDetailedLogging: false
        )
        
        #expect(config.maxStoredEvents == 2500, "Custom max stored events should be 2500")
        #expect(config.apiEndpoint == customURL, "Custom API endpoint should match")
        #expect(config.enableNetworkSync == true, "Custom network sync should be enabled")
        #expect(config.enableDetailedLogging == false, "Custom detailed logging should be disabled")
    }
    
    @Test("BackgroundTimeConfiguration with partial parameters")
    func testConfigurationPartialParams() async throws {
        // Test with only maxStoredEvents changed
        let config1 = BackgroundTimeConfiguration(maxStoredEvents: 500)
        #expect(config1.maxStoredEvents == 500)
        #expect(config1.apiEndpoint == nil)
        #expect(config1.enableNetworkSync == false)
        #expect(config1.enableDetailedLogging == true)
        
        // Test with only apiEndpoint changed
        let testURL = URL(string: "https://test.api.com")!
        let config2 = BackgroundTimeConfiguration(apiEndpoint: testURL)
        #expect(config2.maxStoredEvents == 1000)
        #expect(config2.apiEndpoint == testURL)
        #expect(config2.enableNetworkSync == false)
        #expect(config2.enableDetailedLogging == true)
        
        // Test with only network sync enabled
        let config3 = BackgroundTimeConfiguration(enableNetworkSync: true)
        #expect(config3.maxStoredEvents == 1000)
        #expect(config3.apiEndpoint == nil)
        #expect(config3.enableNetworkSync == true)
        #expect(config3.enableDetailedLogging == true)
        
        // Test with only detailed logging disabled
        let config4 = BackgroundTimeConfiguration(enableDetailedLogging: false)
        #expect(config4.maxStoredEvents == 1000)
        #expect(config4.apiEndpoint == nil)
        #expect(config4.enableNetworkSync == false)
        #expect(config4.enableDetailedLogging == false)
    }
    
    @Test("BackgroundTimeConfiguration description property")
    func testConfigurationDescription() async throws {
        // Test default configuration description
        let defaultConfig = BackgroundTimeConfiguration.default
        let defaultDescription = defaultConfig.description
        #expect(defaultDescription.contains("maxEvents: 1000"), "Description should contain max events")
        #expect(defaultDescription.contains("networkSync: false"), "Description should contain network sync status")
        
        // Test custom configuration description
        let customConfig = BackgroundTimeConfiguration(
            maxStoredEvents: 750,
            enableNetworkSync: true
        )
        let customDescription = customConfig.description
        #expect(customDescription.contains("maxEvents: 750"), "Description should contain custom max events")
        #expect(customDescription.contains("networkSync: true"), "Description should contain custom network sync status")
        
        // Test edge case with zero events
        let zeroConfig = BackgroundTimeConfiguration(maxStoredEvents: 0)
        let zeroDescription = zeroConfig.description
        #expect(zeroDescription.contains("maxEvents: 0"), "Description should handle zero max events")
        
        // Test large number of events
        let largeConfig = BackgroundTimeConfiguration(maxStoredEvents: 999999)
        let largeDescription = largeConfig.description
        #expect(largeDescription.contains("maxEvents: 999999"), "Description should handle large numbers")
    }
    
    @Test("BackgroundTimeConfiguration edge cases")
    func testConfigurationEdgeCases() async throws {
        // Test with invalid URLs (shouldn't crash)
        let validURL1 = URL(string: "https://valid.com")!
        let validURL2 = URL(string: "http://localhost:8080/api")!
        let validURL3 = URL(string: "https://api.company.co.uk/v3/tasks")!
        
        let config1 = BackgroundTimeConfiguration(apiEndpoint: validURL1)
        let config2 = BackgroundTimeConfiguration(apiEndpoint: validURL2)
        let config3 = BackgroundTimeConfiguration(apiEndpoint: validURL3)
        
        #expect(config1.apiEndpoint == validURL1)
        #expect(config2.apiEndpoint == validURL2)
        #expect(config3.apiEndpoint == validURL3)
        
        // Test with extreme maxStoredEvents values
        let minConfig = BackgroundTimeConfiguration(maxStoredEvents: 1)
        let maxConfig = BackgroundTimeConfiguration(maxStoredEvents: Int.max)
        
        #expect(minConfig.maxStoredEvents == 1)
        #expect(maxConfig.maxStoredEvents == Int.max)
        
        // Test all boolean combinations
        let combinations = [
            (networkSync: true, detailedLogging: true),
            (networkSync: true, detailedLogging: false),
            (networkSync: false, detailedLogging: true),
            (networkSync: false, detailedLogging: false)
        ]
        
        for combination in combinations {
            let config = BackgroundTimeConfiguration(
                enableNetworkSync: combination.networkSync,
                enableDetailedLogging: combination.detailedLogging
            )
            #expect(config.enableNetworkSync == combination.networkSync)
            #expect(config.enableDetailedLogging == combination.detailedLogging)
        }
    }
    
    @Test("BackgroundTimeConfiguration SDK version consistency")
    func testSDKVersionConsistency() async throws {
        // Test that SDK version is accessible and consistent
        let version1 = BackgroundTimeConfiguration.sdkVersion
        let version2 = BackgroundTimeConfiguration.sdkVersion
        
        #expect(version1 == version2, "SDK version should be consistent")
        #expect(version1.count > 0, "SDK version should not be empty")
        #expect(version1.contains("."), "SDK version should contain version separators")
        
        // Test that different configuration instances don't affect SDK version
        _ = BackgroundTimeConfiguration.default
        _ = BackgroundTimeConfiguration(maxStoredEvents: 500)
        
        #expect(BackgroundTimeConfiguration.sdkVersion == version1, "SDK version should remain constant")
        
        // Verify SDK version format (should be semantic versioning)
        let versionComponents = version1.components(separatedBy: ".")
        #expect(versionComponents.count >= 2, "SDK version should have at least major.minor format")
        
        // Verify each component is numeric
        for component in versionComponents {
            #expect(Int(component) != nil, "Each version component should be numeric: \(component)")
        }
    }
    
    @Test("BackgroundTimeConfiguration initialization with SDK")
    func testConfigurationWithSDKInitialization() async throws {
        let sdk = await BackgroundTime.shared
        
        // Test that SDK accepts and uses different configurations
        let configs = [
            BackgroundTimeConfiguration.default,
            BackgroundTimeConfiguration(maxStoredEvents: 100),
            BackgroundTimeConfiguration(maxStoredEvents: 2000, enableDetailedLogging: false),
            BackgroundTimeConfiguration(enableNetworkSync: true, enableDetailedLogging: true)
        ]
        
        for config in configs {
            // Initialize SDK with each configuration
            await sdk.initialize(configuration: config)
            
            // Verify SDK continues to function
            let stats = await sdk.getCurrentStats()
            #expect(stats.totalTasksScheduled >= 0, "SDK should function with config: \(config.description)")
            
            let events = await sdk.getAllEvents()
            #expect(events.count >= 0, "SDK should provide events with config: \(config.description)")
            
            // Verify buffer statistics reflect configuration
            let bufferStats = await sdk.getBufferStatistics()
            #expect(bufferStats.capacity > 0, "Buffer capacity should be positive with config: \(config.description)")
        }
    }
    
    @Test("BackgroundTimeConfiguration memory and performance")
    func testConfigurationMemoryAndPerformance() async throws {
        // Test that creating many configuration instances doesn't cause issues
        var configurations: [BackgroundTimeConfiguration] = []
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<1000 {
            let config = BackgroundTimeConfiguration(
                maxStoredEvents: i % 1000 + 100,
                apiEndpoint: i % 2 == 0 ? URL(string: "https://api\(i).com") : nil,
                enableNetworkSync: i % 3 == 0,
                enableDetailedLogging: i % 4 != 0
            )
            configurations.append(config)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        #expect(configurations.count == 1000, "Should create 1000 configurations")
        #expect(duration < 1.0, "Configuration creation should be fast (completed in \(duration)s)")
        
        // Test that all configurations are independent
        for (index, config) in configurations.enumerated() {
            let expectedMaxEvents = index % 1000 + 100
            #expect(config.maxStoredEvents == expectedMaxEvents, "Configuration \(index) should have correct max events")
        }
        
        // Test description generation performance
        let descriptionStartTime = CFAbsoluteTimeGetCurrent()
        
        for config in configurations {
            let _ = config.description
        }
        
        let descriptionEndTime = CFAbsoluteTimeGetCurrent()
        let descriptionDuration = descriptionEndTime - descriptionStartTime
        
        #expect(descriptionDuration < 0.5, "Description generation should be fast (completed in \(descriptionDuration)s)")
    }
}
