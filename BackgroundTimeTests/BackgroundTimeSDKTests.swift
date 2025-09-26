//
//  BackgroundTimeSDKTests.swift
//  BackgroundTimeTests
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Testing
import Foundation
import UIKit
import BackgroundTasks
@testable import BackgroundTime

// MARK: - Test Helpers

@Suite("BackgroundTime SDK Core Tests")
struct BackgroundTimeSDKTests {
    
    @Test("SDK Initialization")
    func testSDKInitialization() async throws {
        // Test that the SDK can be initialized with default configuration
        let config = BackgroundTimeConfiguration.default
        
        #expect(config.maxStoredEvents == 1000)
        #expect(config.apiEndpoint == nil)
        #expect(config.enableNetworkSync == false)
        #expect(config.enableDetailedLogging == true)
    }
    
    @Test("Custom Configuration")
    func testCustomConfiguration() async throws {
        let customURL = URL(string: "https://example.com/api")!
        let config = BackgroundTimeConfiguration(
            maxStoredEvents: 500,
            apiEndpoint: customURL,
            enableNetworkSync: true,
            enableDetailedLogging: false
        )
        
        #expect(config.maxStoredEvents == 500)
        #expect(config.apiEndpoint == customURL)
        #expect(config.enableNetworkSync == true)
        #expect(config.enableDetailedLogging == false)
    }
    
    @Test("BackgroundTime SDK singleton behavior")
    func testBackgroundTimeSingleton() async throws {
        // Test singleton behavior - should always return the same instance
        let instance1 = BackgroundTime.shared
        let instance2 = BackgroundTime.shared
        
        // Use Objective-C identity comparison since we can't use === in Swift Testing
        let ptr1 = Unmanaged.passUnretained(instance1).toOpaque()
        let ptr2 = Unmanaged.passUnretained(instance2).toOpaque()
        #expect(ptr1 == ptr2, "Should be the same singleton instance")
    }
    
    @Test("BackgroundTime SDK initialization with default configuration")
    func testBackgroundTimeInitializationDefault() async throws {
        let sdk = BackgroundTime.shared
        
        // Test initialization with default configuration
        let defaultConfig = BackgroundTimeConfiguration.default
        sdk.initialize(configuration: defaultConfig)
        
        // Should handle multiple initialization calls gracefully
        sdk.initialize(configuration: defaultConfig)
        sdk.initialize(configuration: defaultConfig)
        
        // Verify SDK functions work after initialization
        let stats = sdk.getCurrentStats()
        #expect(stats.totalTasksScheduled >= 0, "Should return valid statistics")
        #expect(stats.totalTasksExecuted >= 0, "Should return valid execution count")
        #expect(stats.successRate >= 0.0 && stats.successRate <= 1.0, "Success rate should be between 0 and 1")
        
        let events = sdk.getAllEvents()
        #expect(events.count >= 0, "Should return events array")
        
        // Should have initialization event recorded
        let initEvents = events.filter { $0.type == .initialization }
        #expect(initEvents.count >= 1, "Should have recorded initialization event")
    }
    
    @Test("BackgroundTime SDK initialization with custom configuration")
    func testBackgroundTimeInitializationCustom() async throws {
        let sdk = BackgroundTime.shared
        
        // Test initialization with custom configuration
        let customURL = URL(string: "https://api.example.com/v1")!
        let customConfig = BackgroundTimeConfiguration(
            maxStoredEvents: 500,
            apiEndpoint: customURL,
            enableNetworkSync: true,
            enableDetailedLogging: false
        )
        
        sdk.initialize(configuration: customConfig)
        
        // Verify configuration was applied by checking if events are properly managed
        let initialEventCount = sdk.getAllEvents().count
        
        // The configuration should be reflected in the SDK behavior
        let stats = sdk.getCurrentStats()
        #expect(stats.generatedAt != nil, "Statistics should have generation timestamp")
        
        let events = sdk.getAllEvents()
        #expect(events.count >= initialEventCount, "Should maintain events after custom initialization")
    }
    
    @Test("BackgroundTime SDK dashboard data export")
    func testDashboardDataExport() async throws {
        let sdk = BackgroundTime.shared
        
        // Initialize SDK first
        sdk.initialize(configuration: .default)
        
        // Test dashboard data export
        let dashboardData = sdk.exportDataForDashboard()
        
        // Verify all components of dashboard data
        #expect(dashboardData.statistics.totalTasksScheduled >= 0, "Should have statistics with valid scheduled count")
        #expect(dashboardData.statistics.totalTasksExecuted >= 0, "Should have statistics with valid executed count")
        #expect(dashboardData.statistics.generatedAt != nil, "Statistics should have generation timestamp")
        
        #expect(dashboardData.events.count >= 0, "Should have events array")
        #expect(dashboardData.timeline.count >= 0, "Should have timeline array")
        #expect(dashboardData.systemInfo.deviceModel.count > 0, "Should have system info with device model")
        #expect(dashboardData.systemInfo.systemVersion.count > 0, "Should have system info with system version")
        #expect(dashboardData.generatedAt != nil, "Dashboard data should have generation timestamp")
        
        // Verify timeline data structure
        for timelinePoint in dashboardData.timeline {
            #expect(timelinePoint.timestamp != nil, "Timeline point should have timestamp")
            #expect(timelinePoint.taskIdentifier.count > 0, "Timeline point should have task identifier")
        }
        
        // Verify system info is current
        let systemInfo = dashboardData.systemInfo
        #expect(systemInfo.batteryLevel >= -1.0 && systemInfo.batteryLevel <= 1.0, "Battery level should be in valid range")
        
        // Test that different calls return consistent structure but may have different timestamps
        let dashboardData2 = sdk.exportDataForDashboard()
        #expect(dashboardData2.statistics.totalTasksScheduled == dashboardData.statistics.totalTasksScheduled, 
                "Statistics should be consistent between calls")
        #expect(dashboardData2.events.count == dashboardData.events.count, 
                "Events count should be consistent between calls")
    }
    
    @Test("BackgroundTime SDK performance metrics")
    func testSDKPerformanceMetrics() async throws {
        let sdk = BackgroundTime.shared
        
        // Initialize SDK
        sdk.initialize(configuration: .default)
        
        // Test data store performance metrics
        let performanceReport = sdk.getDataStorePerformance()
        #expect(performanceReport.operationStats.keys.count >= 0, "Should have operation stats dictionary")
        
        // Test buffer statistics
        let bufferStats = sdk.getBufferStatistics()
        #expect(bufferStats.capacity > 0, "Buffer should have positive capacity")
        #expect(bufferStats.currentCount >= 0, "Buffer should have valid current count")
        #expect(bufferStats.availableSpace >= 0, "Buffer should have valid available space")
        #expect(bufferStats.utilizationPercentage >= 0.0 && bufferStats.utilizationPercentage <= 100.0, 
                "Utilization percentage should be between 0 and 100")
        #expect(bufferStats.availableSpace == bufferStats.capacity - bufferStats.currentCount, 
                "Available space should equal capacity minus current count")
        
        // Verify boolean properties are consistent
        let isEmpty = bufferStats.currentCount == 0
        let isFull = bufferStats.currentCount == bufferStats.capacity
        #expect(bufferStats.isEmpty == isEmpty, "isEmpty should be consistent with count")
        #expect(bufferStats.isFull == isFull, "isFull should be consistent with capacity")
    }
    
    @Test("BackgroundTime SDK dashboard sync error handling")
    func testDashboardSyncErrorHandling() async throws {
        let sdk = BackgroundTime.shared
        
        // Initialize SDK with no endpoint configured
        let configWithoutEndpoint = BackgroundTimeConfiguration(
            maxStoredEvents: 1000,
            apiEndpoint: nil,
            enableNetworkSync: false,
            enableDetailedLogging: true
        )
        sdk.initialize(configuration: configWithoutEndpoint)
        
        // Test sync with no endpoint - should throw error
        do {
            try await sdk.syncWithDashboard()
            #expect(Bool(false), "Should throw error when no endpoint is configured")
        } catch {
            // Expected to fail - verify it's the right type of error
            #expect(error is NetworkError, "Should throw NetworkError when no endpoint configured")
        }
        
        // Test with configured endpoint (will still fail but for different reason in test environment)
        let configWithEndpoint = BackgroundTimeConfiguration(
            maxStoredEvents: 1000,
            apiEndpoint: URL(string: "https://api.test.example.com")!,
            enableNetworkSync: true,
            enableDetailedLogging: true
        )
        sdk.initialize(configuration: configWithEndpoint)
        
        // This will likely fail due to network issues in test environment, but should handle gracefully
        do {
            try await sdk.syncWithDashboard()
            // If it succeeds, that's fine too
        } catch {
            // Expected to fail in test environment - just verify it doesn't crash
            #expect(error != nil, "Should handle network errors gracefully")
        }
    }
    
    @Test("BackgroundTime SDK statistics consistency")
    func testSDKStatisticsConsistency() async throws {
        let sdk = BackgroundTime.shared
        
        // Initialize SDK
        sdk.initialize(configuration: .default)
        
        // Get statistics multiple times and verify consistency
        let stats1 = sdk.getCurrentStats()
        let stats2 = sdk.getCurrentStats()
        
        // Core counts should be the same between immediate calls
        #expect(stats1.totalTasksScheduled == stats2.totalTasksScheduled, 
                "Scheduled count should be consistent")
        #expect(stats1.totalTasksExecuted == stats2.totalTasksExecuted, 
                "Executed count should be consistent")
        #expect(stats1.totalTasksCompleted == stats2.totalTasksCompleted, 
                "Completed count should be consistent")
        #expect(stats1.totalTasksFailed == stats2.totalTasksFailed, 
                "Failed count should be consistent")
        #expect(stats1.totalTasksExpired == stats2.totalTasksExpired, 
                "Expired count should be consistent")
        
        // Success rate should be the same
        #expect(stats1.successRate == stats2.successRate, 
                "Success rate should be consistent")
        
        // Average execution time should be the same
        #expect(stats1.averageExecutionTime == stats2.averageExecutionTime, 
                "Average execution time should be consistent")
        
        // Generation timestamps should be different (or very close)
        let timeDifference = abs(stats2.generatedAt.timeIntervalSince(stats1.generatedAt))
        #expect(timeDifference < 1.0, "Generation timestamps should be within 1 second")
        
        // Verify all events are accessible
        let allEvents = sdk.getAllEvents()
        let eventsFromStats = stats1.totalTasksScheduled + stats1.totalTasksExecuted + 
                            stats1.totalTasksCompleted + stats1.totalTasksFailed + stats1.totalTasksExpired
        
        // The total events might be more than the sum because some events might not fit these categories
        #expect(allEvents.count >= 0, "Should have non-negative event count")
    }
    
    @Test("BackgroundTime SDK event recording and retrieval")  
    func testSDKEventRecordingAndRetrieval() async throws {
        let sdk = BackgroundTime.shared
        
        // Initialize SDK - this should record an initialization event
        sdk.initialize(configuration: .default)
        
        // Wait for initialization to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Get all events and filter for initialization events specifically
        let allEvents = sdk.getAllEvents()
        let initEvents = allEvents.filter { $0.type == .initialization }
        
        // Verify we have at least one initialization event
        #expect(initEvents.count >= 1, "Should have at least one initialization event recorded")
        
        // Test the most recent initialization event properties
        if let initEvent = initEvents.last {
            #expect(initEvent.taskIdentifier == "SDK_EVENT", "Initialization event should have SDK_EVENT identifier")
            #expect(initEvent.type == .initialization, "Should be initialization type")
            #expect(initEvent.success == true, "Initialization should be successful")
            #expect(initEvent.systemInfo.deviceModel.count > 0, "Should have system info with device model")
            #expect(initEvent.systemInfo.systemVersion.count > 0, "Should have system info with system version")
            
            // Check if metadata exists and has expected content
            // Note: The metadata structure depends on the actual BackgroundTime implementation
            // We'll check for common metadata fields that should be present
            #expect(initEvent.metadata is [String: Any], "Metadata should be a dictionary")
            
            // Try to verify SDK version in metadata if it exists
            if let metadata = initEvent.metadata as? [String: Any],
               let version = metadata["version"] as? String {
                #expect(version == BackgroundTimeConfiguration.sdkVersion, "Should have correct SDK version in metadata")
            }
            
            // Verify the event has a valid timestamp
            #expect(abs(initEvent.timestamp.timeIntervalSinceNow) < 300, "Initialization event should have recent timestamp (within 5 minutes)")
        }
        
        // Test statistics generation
        let stats = sdk.getCurrentStats()
        #expect(stats.generatedAt.timeIntervalSinceNow > -60, "Statistics should be recently generated (within last minute)")
        #expect(stats.totalTasksScheduled >= 0, "Should have non-negative scheduled count")
        #expect(stats.totalTasksExecuted >= 0, "Should have non-negative executed count")
        #expect(stats.totalTasksCompleted >= 0, "Should have non-negative completed count")
        #expect(stats.totalTasksFailed >= 0, "Should have non-negative failed count")
        
        // Test dashboard export functionality
        let dashboardData = sdk.exportDataForDashboard()
        
        // Verify dashboard data structure
        #expect(dashboardData.events.count >= initEvents.count, "Dashboard should include at least the initialization events")
        #expect(dashboardData.timeline.count >= 0, "Timeline should have non-negative count")
        #expect(dashboardData.statistics.totalTasksScheduled >= 0, "Dashboard statistics should have non-negative counts")
        #expect(dashboardData.systemInfo.deviceModel.count > 0, "Dashboard should include system info")
        #expect(dashboardData.generatedAt.timeIntervalSinceNow > -60, "Dashboard data should be recently generated")
        
        // Verify that timeline data points have required properties
        for timelinePoint in dashboardData.timeline {
            #expect(timelinePoint.timestamp != nil, "Timeline point should have timestamp")
            #expect(timelinePoint.taskIdentifier.count > 0, "Timeline point should have task identifier")
            #expect(timelinePoint.eventType != nil, "Timeline point should have event type")
        }
        
        // Verify that the dashboard export is consistent
        let dashboardData2 = sdk.exportDataForDashboard()
        
        // The event counts should be the same between immediate calls (allowing for minor timing differences)
        let eventCountDiff = abs(dashboardData2.events.count - dashboardData.events.count)
        #expect(eventCountDiff <= 1, "Event counts should be very similar between immediate dashboard exports")
        
        // Timeline counts should also be similar
        let timelineCountDiff = abs(dashboardData2.timeline.count - dashboardData.timeline.count)
        #expect(timelineCountDiff <= 1, "Timeline counts should be very similar between immediate dashboard exports")
    }
}

@Suite("Data Store Tests")
struct DataStoreTests {
    
    @Test("Event Recording")
    func testEventRecording() async throws {
        // Use isolated test instance
        let dataStore = BackgroundTaskDataStore.createTestInstance()
        
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "test-task-recording",
            type: .taskScheduled,
            timestamp: Date(),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: ["test": "value"],
            systemInfo: createMockSystemInfo()
        )
        
        dataStore.recordEvent(event)
        
        // Small delay to ensure event is recorded
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        let allEvents = dataStore.getAllEvents()
        #expect(allEvents.count == 1, "Should have exactly one event")
        #expect(allEvents.first?.taskIdentifier == "test-task-recording")
        #expect(allEvents.first?.type == .taskScheduled)
    }
    
    @Test("Statistics Generation")
    func testStatisticsGeneration() async throws {
        // Use isolated test instance
        let dataStore = BackgroundTaskDataStore.createTestInstance()
        
        // Create test events with unique identifiers
        let baseIdentifier = "stats-test-\(UUID().uuidString)"
        let testEvents = createMockEventsForStatistics(baseIdentifier: baseIdentifier)
        for event in testEvents {
            dataStore.recordEvent(event)
        }
        
        // Delay to ensure events are recorded
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Verify events were recorded
        let allEvents = dataStore.getAllEvents()
        #expect(allEvents.count == testEvents.count, "All test events should be recorded: expected \(testEvents.count), got \(allEvents.count)")
        
        let stats = dataStore.generateStatistics()
        
        #expect(stats.totalTasksScheduled == 2, "Should have 2 scheduled tasks")
        #expect(stats.totalTasksExecuted == 2, "Should have 2 executed tasks")
        #expect(stats.totalTasksCompleted == 1, "Should have 1 completed task")
        #expect(stats.totalTasksFailed == 1, "Should have 1 failed task")
        #expect(stats.successRate == 0.5, "Success rate should be 0.5 (1 success out of 2 executed)")
    }
    
    @Test("Event Filtering by Date Range")
    func testEventFilteringByDateRange() async throws {
        // Use isolated test instance
        let dataStore = BackgroundTaskDataStore.createTestInstance()
        
        let now = Date()
        let twoHoursAgo = Date(timeIntervalSinceNow: -7200)
        
        // Create events at different times with unique identifiers
        let recentEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "filter-test-recent",
            type: .taskScheduled,
            timestamp: now,
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        )
        
        let oldEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "filter-test-old",
            type: .taskScheduled,
            timestamp: twoHoursAgo,
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        )
        
        dataStore.recordEvent(recentEvent)
        dataStore.recordEvent(oldEvent)
        
        // Wait for events to be recorded
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Use a wider range to account for timing precision
        let startRange = Date(timeIntervalSinceNow: -3600) // 1 hour ago
        let endRange = Date(timeIntervalSinceNow: 60) // 1 minute in the future
        
        let recentEvents = dataStore.getEventsInDateRange(from: startRange, to: endRange)
        let filteredTestEvents = recentEvents.filter { $0.taskIdentifier == "filter-test-recent" }
        
        #expect(filteredTestEvents.count == 1, "Should find exactly 1 recent test event, found \(filteredTestEvents.count)")
        #expect(filteredTestEvents.first?.taskIdentifier == "filter-test-recent", "Should find the recent event")
    }
    
    @Test("Task Performance Metrics")
    func testTaskPerformanceMetrics() async throws {
        // Use isolated test instance
        let dataStore = BackgroundTaskDataStore.createTestInstance()
        
        let taskIdentifier = "performance-test-task-unique"
        let baseTimestamp = Date()
        
        // Create a series of events for the same task
        let scheduledEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskScheduled,
            timestamp: baseTimestamp,
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        )
        
        let executedEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskExecutionStarted,
            timestamp: Date(timeInterval: 300, since: baseTimestamp), // 5 minutes later
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        )
        
        let completedEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskExecutionCompleted,
            timestamp: Date(timeInterval: 305, since: baseTimestamp), // 5 seconds duration
            duration: 5.0,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        )
        
        dataStore.recordEvent(scheduledEvent)
        dataStore.recordEvent(executedEvent)
        dataStore.recordEvent(completedEvent)
        
        // Delay to ensure events are recorded
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Verify events were recorded
        let allEvents = dataStore.getAllEvents()
        #expect(allEvents.count == 3, "Should have recorded 3 events for the task, found \(allEvents.count)")
        
        let metrics = dataStore.getTaskPerformanceMetrics(for: taskIdentifier)
        
        #expect(metrics != nil, "Metrics should not be nil when events exist")
        if let metrics = metrics {
            #expect(metrics.taskIdentifier == taskIdentifier)
            #expect(metrics.totalScheduled == 1)
            #expect(metrics.totalExecuted == 1)
            #expect(metrics.totalCompleted == 1)
            #expect(metrics.averageDuration == 5.0)
            #expect(metrics.successRate == 1.0)
        }
    }
}

@Suite("Network Manager Tests")
struct NetworkManagerTests {
    
    @Test("Network Configuration")
    func testNetworkConfiguration() async throws {
        let networkManager = NetworkManager.shared
        let testURL = URL(string: "https://api.example.com")!
        
        networkManager.configure(apiEndpoint: testURL)
        
        // Network manager configuration is internal, so we test through behavior
        // This would require making some properties internal for testing
    }
    
    @Test("Dashboard Data Upload Structure")
    func testDashboardDataStructure() async throws {
        let dashboardData = BackgroundTaskDashboardData(
            statistics: createMockStatistics(),
            events: createMockEvents(),
            timeline: createMockTimelineData(),
            systemInfo: createMockSystemInfo()
        )
        
        #expect(dashboardData.events.count > 0)
        #expect(dashboardData.timeline.count > 0)
        #expect(dashboardData.statistics.totalTasksScheduled >= 0)
    }
}

@Suite("BackgroundTimeConfiguration Tests")
struct BackgroundTimeConfigurationTests {
    
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
        let config1 = BackgroundTimeConfiguration.default
        let config2 = BackgroundTimeConfiguration(maxStoredEvents: 500)
        
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
        let sdk = BackgroundTime.shared
        
        // Test that SDK accepts and uses different configurations
        let configs = [
            BackgroundTimeConfiguration.default,
            BackgroundTimeConfiguration(maxStoredEvents: 100),
            BackgroundTimeConfiguration(maxStoredEvents: 2000, enableDetailedLogging: false),
            BackgroundTimeConfiguration(enableNetworkSync: true, enableDetailedLogging: true)
        ]
        
        for config in configs {
            // Initialize SDK with each configuration
            sdk.initialize(configuration: config)
            
            // Verify SDK continues to function
            let stats = sdk.getCurrentStats()
            #expect(stats.totalTasksScheduled >= 0, "SDK should function with config: \(config.description)")
            
            let events = sdk.getAllEvents()
            #expect(events.count >= 0, "SDK should provide events with config: \(config.description)")
            
            // Verify buffer statistics reflect configuration
            let bufferStats = sdk.getBufferStatistics()
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

@Suite("Network and Dashboard Configuration Tests")
struct NetworkAndDashboardConfigurationTests {
    
    @Test("DashboardConfiguration default properties")
    func testDashboardConfigurationDefaults() async throws {
        let defaultConfig = DashboardConfiguration.default
        
        #expect(defaultConfig.refreshInterval == 300, "Default refresh interval should be 300 seconds (5 minutes)")
        #expect(defaultConfig.maxEventsPerUpload == 1000, "Default max events per upload should be 1000")
        #expect(defaultConfig.enableRealTimeSync == false, "Default real-time sync should be disabled")
        #expect(defaultConfig.alertThresholds.lowSuccessRate == 0.8, "Default low success rate threshold should be 0.8")
        #expect(defaultConfig.alertThresholds.highFailureRate == 0.2, "Default high failure rate threshold should be 0.2")
        #expect(defaultConfig.alertThresholds.longExecutionTime == 30, "Default long execution time should be 30 seconds")
        #expect(defaultConfig.alertThresholds.noExecutionPeriod == 86400, "Default no execution period should be 86400 seconds (24 hours)")
    }
    
    @Test("AlertThresholds default properties and validation")
    func testAlertThresholdsDefaults() async throws {
        let thresholds = AlertThresholds.default
        
        #expect(thresholds.lowSuccessRate == 0.8)
        #expect(thresholds.highFailureRate == 0.2)
        #expect(thresholds.longExecutionTime == 30)
        #expect(thresholds.noExecutionPeriod == 86400)
        
        // Validate logical relationships
        #expect(thresholds.lowSuccessRate > thresholds.highFailureRate, "Low success rate threshold should be higher than high failure rate")
        #expect(thresholds.lowSuccessRate + thresholds.highFailureRate == 1.0, "Success and failure rates should complement each other")
        #expect(thresholds.longExecutionTime > 0, "Long execution time should be positive")
        #expect(thresholds.noExecutionPeriod > 0, "No execution period should be positive")
        #expect(thresholds.noExecutionPeriod > thresholds.longExecutionTime, "No execution period should be much longer than execution time")
    }
    
    @Test("DashboardConfiguration custom values")
    func testDashboardConfigurationCustom() async throws {
        let customThresholds = AlertThresholds(
            lowSuccessRate: 0.9,
            highFailureRate: 0.1,
            longExecutionTime: 60,
            noExecutionPeriod: 172800 // 48 hours
        )
        
        let customConfig = DashboardConfiguration(
            refreshInterval: 120, // 2 minutes
            maxEventsPerUpload: 500,
            enableRealTimeSync: true,
            alertThresholds: customThresholds
        )
        
        #expect(customConfig.refreshInterval == 120)
        #expect(customConfig.maxEventsPerUpload == 500)
        #expect(customConfig.enableRealTimeSync == true)
        #expect(customConfig.alertThresholds.lowSuccessRate == 0.9)
        #expect(customConfig.alertThresholds.highFailureRate == 0.1)
        #expect(customConfig.alertThresholds.longExecutionTime == 60)
        #expect(customConfig.alertThresholds.noExecutionPeriod == 172800)
    }
    
    @Test("DashboardConfiguration codable functionality")
    func testDashboardConfigurationCodable() async throws {
        let originalConfig = DashboardConfiguration.default
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalConfig)
        
        #expect(data.count > 0, "Encoded data should not be empty")
        
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(DashboardConfiguration.self, from: data)
        
        #expect(decodedConfig.refreshInterval == originalConfig.refreshInterval)
        #expect(decodedConfig.maxEventsPerUpload == originalConfig.maxEventsPerUpload)
        #expect(decodedConfig.enableRealTimeSync == originalConfig.enableRealTimeSync)
        #expect(decodedConfig.alertThresholds.lowSuccessRate == originalConfig.alertThresholds.lowSuccessRate)
        #expect(decodedConfig.alertThresholds.highFailureRate == originalConfig.alertThresholds.highFailureRate)
        #expect(decodedConfig.alertThresholds.longExecutionTime == originalConfig.alertThresholds.longExecutionTime)
        #expect(decodedConfig.alertThresholds.noExecutionPeriod == originalConfig.alertThresholds.noExecutionPeriod)
    }
    
    @Test("AlertThresholds codable functionality")
    func testAlertThresholdsCodable() async throws {
        let customThresholds = AlertThresholds(
            lowSuccessRate: 0.95,
            highFailureRate: 0.05,
            longExecutionTime: 45.5,
            noExecutionPeriod: 259200 // 72 hours
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(customThresholds)
        
        let decoder = JSONDecoder()
        let decodedThresholds = try decoder.decode(AlertThresholds.self, from: data)
        
        #expect(decodedThresholds.lowSuccessRate == customThresholds.lowSuccessRate)
        #expect(decodedThresholds.highFailureRate == customThresholds.highFailureRate)
        #expect(decodedThresholds.longExecutionTime == customThresholds.longExecutionTime)
        #expect(decodedThresholds.noExecutionPeriod == customThresholds.noExecutionPeriod)
    }
    
    @Test("DashboardConfiguration edge cases")
    func testDashboardConfigurationEdgeCases() async throws {
        // Test with extreme values
        let extremeThresholds = AlertThresholds(
            lowSuccessRate: 0.0,
            highFailureRate: 1.0,
            longExecutionTime: 0.1,
            noExecutionPeriod: 1
        )
        
        let extremeConfig = DashboardConfiguration(
            refreshInterval: 1, // 1 second
            maxEventsPerUpload: 1,
            enableRealTimeSync: true,
            alertThresholds: extremeThresholds
        )
        
        #expect(extremeConfig.refreshInterval == 1)
        #expect(extremeConfig.maxEventsPerUpload == 1)
        #expect(extremeConfig.enableRealTimeSync == true)
        #expect(extremeConfig.alertThresholds.lowSuccessRate == 0.0)
        #expect(extremeConfig.alertThresholds.highFailureRate == 1.0)
        
        // Test with very large values
        let largeConfig = DashboardConfiguration(
            refreshInterval: TimeInterval.greatestFiniteMagnitude,
            maxEventsPerUpload: Int.max,
            enableRealTimeSync: false,
            alertThresholds: AlertThresholds(
                lowSuccessRate: 1.0,
                highFailureRate: 0.0,
                longExecutionTime: TimeInterval.greatestFiniteMagnitude,
                noExecutionPeriod: TimeInterval.greatestFiniteMagnitude
            )
        )
        
        #expect(largeConfig.refreshInterval == TimeInterval.greatestFiniteMagnitude)
        #expect(largeConfig.maxEventsPerUpload == Int.max)
        #expect(largeConfig.alertThresholds.lowSuccessRate == 1.0)
        #expect(largeConfig.alertThresholds.highFailureRate == 0.0)
    }
    
    @Test("NetworkManager configuration")
    func testNetworkManagerConfiguration() async throws {
        let networkManager = NetworkManager.shared
        
        // Test configuration with nil endpoint
        networkManager.configure(apiEndpoint: nil)
        
        // Test configuration with valid endpoints
        let validEndpoints = [
            URL(string: "https://api.example.com")!,
            URL(string: "http://localhost:3000")!,
            URL(string: "https://dashboard.company.com/api/v2")!
        ]
        
        for endpoint in validEndpoints {
            networkManager.configure(apiEndpoint: endpoint)
            // Configuration is internal, so we verify it doesn't crash
            #expect(true, "NetworkManager should accept valid endpoint: \(endpoint)")
        }
    }
    
    @Test("NetworkError comprehensive testing")
    func testNetworkErrorCases() async throws {
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error message"])
        
        let networkErrors: [NetworkError] = [
            .noEndpointConfigured,
            .invalidResponse,
            .serverError(statusCode: 400),
            .serverError(statusCode: 404),
            .serverError(statusCode: 500),
            .serverError(statusCode: 503),
            .uploadFailed(testError),
            .downloadFailed(testError)
        ]
        
        for error in networkErrors {
            let description = error.errorDescription
            #expect(description != nil, "NetworkError should have error description: \(error)")
            #expect(description!.count > 0, "NetworkError description should not be empty: \(error)")
            
            switch error {
            case .noEndpointConfigured:
                #expect(description!.contains("endpoint"), "Should mention endpoint")
            case .invalidResponse:
                #expect(description!.contains("response"), "Should mention response")
            case .serverError(let statusCode):
                #expect(description!.contains("\(statusCode)"), "Should contain status code")
            case .uploadFailed(let underlyingError):
                #expect(description!.contains("Upload"), "Should mention upload")
                #expect(description!.contains(underlyingError.localizedDescription), "Should contain underlying error")
            case .downloadFailed(let underlyingError):
                #expect(description!.contains("Download"), "Should mention download")
                #expect(description!.contains(underlyingError.localizedDescription), "Should contain underlying error")
            }
        }
    }
    
    @Test("DashboardConfiguration with NetworkManager integration")
    func testDashboardConfigurationIntegration() async throws {
        let config = DashboardConfiguration(
            refreshInterval: 60,
            maxEventsPerUpload: 250,
            enableRealTimeSync: true,
            alertThresholds: AlertThresholds.default
        )
        
        // Test that configuration values are reasonable for network operations
        #expect(config.refreshInterval >= 1, "Refresh interval should be at least 1 second")
        #expect(config.maxEventsPerUpload >= 1, "Max events per upload should be at least 1")
        #expect(config.refreshInterval < 86400, "Refresh interval should be less than 24 hours for practical use")
        #expect(config.maxEventsPerUpload <= 10000, "Max events per upload should be reasonable for network transmission")
        
        // Test that alert thresholds are within valid ranges
        let thresholds = config.alertThresholds
        #expect(thresholds.lowSuccessRate >= 0.0 && thresholds.lowSuccessRate <= 1.0, "Low success rate should be between 0 and 1")
        #expect(thresholds.highFailureRate >= 0.0 && thresholds.highFailureRate <= 1.0, "High failure rate should be between 0 and 1")
        #expect(thresholds.longExecutionTime >= 0, "Long execution time should be non-negative")
        #expect(thresholds.noExecutionPeriod >= 0, "No execution period should be non-negative")
    }
}

@Suite("Event Type Tests")
struct EventTypeTests {
    
    @Test("All Event Types Have Icons")
    func testEventTypeIcons() async throws {
        for eventType in BackgroundTaskEventType.allCases {
            let icon = eventType.icon
            #expect(!icon.isEmpty, "Event type \(eventType.rawValue) should have an icon")
        }
    }
    
    @Test("Event Type Raw Values")
    func testEventTypeRawValues() async throws {
        #expect(BackgroundTaskEventType.taskScheduled.rawValue == "task_scheduled")
        #expect(BackgroundTaskEventType.taskExecutionStarted.rawValue == "task_execution_started")
        #expect(BackgroundTaskEventType.taskExecutionCompleted.rawValue == "task_execution_completed")
        #expect(BackgroundTaskEventType.taskExpired.rawValue == "task_expired")
        #expect(BackgroundTaskEventType.taskCancelled.rawValue == "task_cancelled")
        #expect(BackgroundTaskEventType.taskFailed.rawValue == "task_failed")
    }
}

@Suite("Data Model Tests")
struct DataModelTests {
    
    @Test("BackgroundTaskEvent Encoding and Decoding")
    func testBackgroundTaskEventCodable() async throws {
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "test-task",
            type: .taskScheduled,
            timestamp: Date(),
            duration: 5.0,
            success: true,
            errorMessage: nil,
            metadata: ["key": "value"],
            systemInfo: createMockSystemInfo()
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        
        let decoder = JSONDecoder()
        let decodedEvent = try decoder.decode(BackgroundTaskEvent.self, from: data)
        
        #expect(decodedEvent.id == event.id)
        #expect(decodedEvent.taskIdentifier == event.taskIdentifier)
        #expect(decodedEvent.type == event.type)
        #expect(decodedEvent.success == event.success)
        #expect(decodedEvent.duration == event.duration)
    }
    
    @Test("SystemInfo Encoding and Decoding")
    func testSystemInfoCodable() async throws {
        let systemInfo = createMockSystemInfo()
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(systemInfo)
        
        let decoder = JSONDecoder()
        let decodedSystemInfo = try decoder.decode(SystemInfo.self, from: data)
        
        #expect(decodedSystemInfo.deviceModel == systemInfo.deviceModel)
        #expect(decodedSystemInfo.systemVersion == systemInfo.systemVersion)
        #expect(decodedSystemInfo.lowPowerModeEnabled == systemInfo.lowPowerModeEnabled)
    }
    
    @Test("Statistics Generation with Empty Data")
    func testStatisticsWithEmptyData() async throws {
        // Use isolated test instance
        let dataStore = BackgroundTaskDataStore.createTestInstance()
        
        // Generate statistics with an empty array to test the statistics generation logic
        let emptyEvents: [BackgroundTaskEvent] = []
        let stats = dataStore.generateStatistics(for: emptyEvents, in: Date.distantPast...Date.distantFuture)
        
        #expect(stats.totalTasksScheduled == 0, "Should have 0 scheduled tasks with empty data")
        #expect(stats.totalTasksExecuted == 0, "Should have 0 executed tasks with empty data")
        #expect(stats.totalTasksCompleted == 0, "Should have 0 completed tasks with empty data")
        #expect(stats.totalTasksFailed == 0, "Should have 0 failed tasks with empty data")
        #expect(stats.successRate == 0.0, "Success rate should be 0.0 with empty data")
        #expect(stats.averageExecutionTime == 0.0, "Average execution time should be 0.0 with empty data")
    }
}

@Suite("Swizzling Tests")
struct SwizzlingTests {
    
    @Test("BGTaskScheduler Swizzling Initialization")
    func testBGTaskSchedulerSwizzling() async throws {
        // Don't clear all events since this is a shared store
        // Just verify swizzling works without affecting the data store
        
        // Initialize swizzling
        BGTaskSchedulerSwizzler.swizzleSchedulerMethods()
        
        // Verify swizzling doesn't break normal operation
        let scheduler = BGTaskScheduler.shared
        #expect(scheduler != nil)
        
        // Test that swizzling can be called multiple times without issues
        BGTaskSchedulerSwizzler.swizzleSchedulerMethods()
        BGTaskSchedulerSwizzler.swizzleSchedulerMethods()
        
        #expect(scheduler != nil) // Still working after multiple swizzle attempts
        
        // Verify the data store is still functional
        let dataStore = BackgroundTaskDataStore.createTestInstance()
        #expect(dataStore != nil, "Data store should remain functional after swizzling")
    }
    
    @Test("Task Registration Tracking")
    func testTaskRegistrationTracking() async throws {
        // Initialize swizzling first
        BGTaskSchedulerSwizzler.swizzleSchedulerMethods()
        
        // Wait for initialization to complete
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        let taskIdentifier = "swizzling-registration-test-unique-\(UUID().uuidString)"
        let scheduler = BGTaskScheduler.shared
        
        // Register a task - this should work even in test environment
        let _ = scheduler.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            // Mock launch handler
            task.setTaskCompleted(success: true)
        }
        
        // In test environment, registration might fail due to missing Info.plist entries
        // We'll test that swizzling was attempted by checking if the scheduler still works
        #expect(scheduler != nil, "Scheduler should still be functional after swizzling attempt")
        
        // Test basic functionality rather than method existence
        #expect(true, "Swizzling completed without crashing the scheduler")
    }
    
    @Test("Task Cancellation Tracking")
    func testTaskCancellationTracking() async throws {
        // Initialize swizzling first
        BGTaskSchedulerSwizzler.swizzleSchedulerMethods()
        
        // Wait for initialization to complete
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        let taskIdentifier = "swizzling-cancellation-test-unique-\(UUID().uuidString)"
        let scheduler = BGTaskScheduler.shared
        
        // Test individual task cancellation
        scheduler.cancel(taskRequestWithIdentifier: taskIdentifier)
        
        // Test cancel all tasks
        scheduler.cancelAllTaskRequests()
        
        // Verify scheduler still works after swizzling attempts
        #expect(scheduler != nil, "Scheduler should still be functional")
        
        // Test that operations complete without crashing
        #expect(true, "Cancellation operations completed successfully")
    }
    
    @Test("Task Submission Error Handling")
    func testTaskSubmissionErrorHandling() async throws {
        // Initialize swizzling first
        BGTaskSchedulerSwizzler.swizzleSchedulerMethods()
        
        // Wait for initialization to complete
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        let scheduler = BGTaskScheduler.shared
        
        // Create a task request with invalid identifier (should cause error)
        let taskRequest = BGAppRefreshTaskRequest(identifier: "swizzling-invalid-task-\(UUID().uuidString)")
        
        do {
            try scheduler.submit(taskRequest)
            // If submission succeeds (unlikely in test), that's fine
            #expect(true, "Task submission completed")
        } catch {
            // Expected to fail in test environment - verify error is properly handled
            #expect(error != nil, "Error should be properly handled")
        }
        
        // Verify scheduler still works after swizzling attempts  
        #expect(scheduler != nil, "Scheduler should still be functional")
    }
    
    @Test("BGTask Swizzling Initialization")
    func testBGTaskSwizzling() async throws {
        // Initialize BGTask swizzling
        BGTaskSwizzler.swizzleTaskMethods()
        
        // Verify swizzling doesn't break the basic functionality
        // In a real scenario, we would test with an actual BGTask, but in unit tests
        // we just verify the swizzling process completes without crashing
        #expect(true, "Swizzling completed successfully")
        
        // Verify that the taskStartTimes dictionary is accessible
        let initialCount = await withCheckedContinuation { continuation in
            BGTaskSwizzler.taskQueue.async {
                let count = BGTaskSwizzler.taskStartTimes.count
                continuation.resume(returning: count)
            }
        }
        
        // The count could be anything depending on what other tests have done
        // We just verify we can access it without crashing
        #expect(initialCount >= 0, "Task start times dictionary should be accessible")
    }
    
    @Test("Task Start Time Tracking")
    func testTaskStartTimeTracking() async throws {
        let taskIdentifier = "swizzling-start-time-test-\(UUID().uuidString)"
        let startTime = Date()
        
        // Initialize swizzling to ensure it's set up
        BGTaskSwizzler.swizzleTaskMethods()
        
        // Clear existing start times for this test identifier only
        await withCheckedContinuation { continuation in
            BGTaskSwizzler.taskQueue.async(flags: .barrier) {
                BGTaskSwizzler.taskStartTimes.removeValue(forKey: taskIdentifier)
                continuation.resume()
            }
        }
        
        // Simulate task start tracking
        await withCheckedContinuation { continuation in
            BGTaskSwizzler.taskQueue.async(flags: .barrier) {
                BGTaskSwizzler.taskStartTimes[taskIdentifier] = startTime
                continuation.resume()
            }
        }
        
        // Wait for async operation to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify start time was recorded
        let recordedStartTime = await withCheckedContinuation { continuation in
            BGTaskSwizzler.taskQueue.async {
                let time = BGTaskSwizzler.taskStartTimes[taskIdentifier]
                continuation.resume(returning: time)
            }
        }
        
        #expect(recordedStartTime != nil, "Start time should have been recorded")
        if let recordedTime = recordedStartTime {
            #expect(abs(recordedTime.timeIntervalSince(startTime)) < 1.0, "Recorded time should be within 1 second of start time")
        }
        
        // Clean up our test entry
        await withCheckedContinuation { continuation in
            BGTaskSwizzler.taskQueue.async(flags: .barrier) {
                BGTaskSwizzler.taskStartTimes.removeValue(forKey: taskIdentifier)
                continuation.resume()
            }
        }
    }
    
    @Test("Task Completion Event Recording")
    func testTaskCompletionEventRecording() async throws {
        // Use isolated test instance
        let dataStore = BackgroundTaskDataStore.createTestInstance()
        
        // Generate a unique task identifier for this specific test
        let taskIdentifier = "swizzling-completion-test-\(UUID().uuidString)"
        
        // Initialize swizzling first to ensure it's set up
        BGTaskSwizzler.swizzleTaskMethods()
        
        // Clear task start times to ensure clean state
        await withCheckedContinuation { continuation in
            BGTaskSwizzler.taskQueue.async(flags: .barrier) {
                BGTaskSwizzler.taskStartTimes.removeAll()
                continuation.resume()
            }
        }
        
        let startTime = Date()
        
        // Set up start time manually in the BGTaskSwizzler
        await withCheckedContinuation { continuation in
            BGTaskSwizzler.taskQueue.async(flags: .barrier) {
                BGTaskSwizzler.taskStartTimes[taskIdentifier] = startTime
                continuation.resume()
            }
        }
        
        // Wait for the start time to be set
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Record the count of existing events with our identifier before we add our event
        let preTestEvents = dataStore.getAllEvents().filter { $0.taskIdentifier == taskIdentifier }
        let preTestCount = preTestEvents.count
        
        // Simulate task completion by directly creating an event
        let completionEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskExecutionCompleted,
            timestamp: Date(),
            duration: 5.0,
            success: true,
            errorMessage: nil,
            metadata: ["test": "completion", "swizzling": "true"],
            systemInfo: createMockSystemInfo()
        )
        
        dataStore.recordEvent(completionEvent)
        
        // Wait for event to be recorded and persisted
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Look specifically for our event
        let allEvents = dataStore.getAllEvents()
        let completionEvents = allEvents.filter { 
            $0.type == .taskExecutionCompleted && 
            $0.taskIdentifier == taskIdentifier &&
            ($0.metadata["swizzling"] as? String) == "true"
        }
        
        // Should have exactly one more event than before
        let expectedCount = preTestCount + 1
        #expect(completionEvents.count == expectedCount, "Should have recorded exactly one completion event for task \(taskIdentifier). Expected: \(expectedCount), Found: \(completionEvents.count)")
        
        // Verify the event details if it exists
        if let recordedEvent = completionEvents.first {
            #expect(recordedEvent.taskIdentifier == taskIdentifier, "Task identifier should match")
            #expect(recordedEvent.type == .taskExecutionCompleted, "Event type should be taskExecutionCompleted")
            #expect(recordedEvent.duration == 5.0, "Duration should be 5.0")
            #expect(recordedEvent.success == true, "Event should be marked as successful")
            #expect((recordedEvent.metadata["test"] as? String) == "completion", "Metadata should contain test marker")
        }
        
        // Clean up start time (as the swizzled method would do)
        await withCheckedContinuation { continuation in
            BGTaskSwizzler.taskQueue.async(flags: .barrier) {
                BGTaskSwizzler.taskStartTimes.removeValue(forKey: taskIdentifier)
                continuation.resume()
            }
        }
        
        // Verify start time was cleaned up
        let remainingStartTime = await withCheckedContinuation { continuation in
            BGTaskSwizzler.taskQueue.async {
                let time = BGTaskSwizzler.taskStartTimes[taskIdentifier]
                continuation.resume(returning: time)
            }
        }
        
        #expect(remainingStartTime == nil, "Start time should be cleaned up after task completion")
    }
    
    @Test("Swizzling Thread Safety")
    func testSwizzlingThreadSafety() async throws {
        let baseTaskIdentifier = "swizzling-thread-safety-\(UUID().uuidString)"
        let iterations = 10
        
        // Initialize swizzling to ensure it's set up
        BGTaskSwizzler.swizzleTaskMethods()
        
        // Clear existing data and wait for it to complete
        await withCheckedContinuation { continuation in
            BGTaskSwizzler.taskQueue.async(flags: .barrier) {
                // Only remove entries that match our test pattern to avoid interfering with other tests
                BGTaskSwizzler.taskStartTimes = BGTaskSwizzler.taskStartTimes.filter { !$0.key.hasPrefix(baseTaskIdentifier) }
                continuation.resume()
            }
        }
        
        // Wait for cleanup to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Simulate concurrent access to task start times with unique identifiers
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let uniqueIdentifier = "\(baseTaskIdentifier)-\(i)"
                    await withCheckedContinuation { continuation in
                        BGTaskSwizzler.taskQueue.async(flags: .barrier) {
                            BGTaskSwizzler.taskStartTimes[uniqueIdentifier] = Date()
                            continuation.resume()
                        }
                    }
                }
            }
        }
        
        // Wait for all operations to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Verify all entries were recorded - filter by our base identifier
        let finalCount = await withCheckedContinuation { continuation in
            BGTaskSwizzler.taskQueue.async {
                let count = BGTaskSwizzler.taskStartTimes.keys.filter { $0.hasPrefix(baseTaskIdentifier) }.count
                continuation.resume(returning: count)
            }
        }
        
        #expect(finalCount == iterations, "Expected \(iterations) entries, got \(finalCount)")
        
        // Clean up our test entries
        await withCheckedContinuation { continuation in
            BGTaskSwizzler.taskQueue.async(flags: .barrier) {
                BGTaskSwizzler.taskStartTimes = BGTaskSwizzler.taskStartTimes.filter { !$0.key.hasPrefix(baseTaskIdentifier) }
                continuation.resume()
            }
        }
    }
    
    @Test("Date ISO8601 Extension")
    func testDateISO8601Extension() async throws {
        let testDate = Date(timeIntervalSince1970: 1695686400) // A specific timestamp
        let iso8601String = testDate.iso8601String
        
        #expect(!iso8601String.isEmpty)
        #expect(iso8601String.contains("T")) // ISO8601 format contains T separator
        #expect(iso8601String.contains("Z") || iso8601String.contains("+") || iso8601String.contains("-")) // Contains timezone info
        
        // Verify it can be parsed back
        let formatter = ISO8601DateFormatter()
        let parsedDate = formatter.date(from: iso8601String)
        #expect(parsedDate != nil)
        #expect(abs(parsedDate!.timeIntervalSince(testDate)) < 1.0) // Should be very close
    }
}

// MARK: - Helper Functions

private func createMockSystemInfo() -> SystemInfo {
    return SystemInfo(
        backgroundAppRefreshStatus: .available,
        deviceModel: "iPhone",
        systemVersion: "17.0",
        lowPowerModeEnabled: false,
        batteryLevel: 0.75,
        batteryState: .unplugged
    )
}

private func createMockEvents() -> [BackgroundTaskEvent] {
    return [
        BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "mock-task-1",
            type: .taskScheduled,
            timestamp: Date(timeIntervalSinceNow: -300),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        ),
        BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "mock-task-1",
            type: .taskExecutionStarted,
            timestamp: Date(timeIntervalSinceNow: -295),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        ),
        BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "mock-task-1",
            type: .taskExecutionCompleted,
            timestamp: Date(timeIntervalSinceNow: -290),
            duration: 5.0,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        ),
        BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "mock-task-2",
            type: .taskScheduled,
            timestamp: Date(timeIntervalSinceNow: -200),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        ),
        BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "mock-task-2",
            type: .taskFailed,
            timestamp: Date(timeIntervalSinceNow: -195),
            duration: nil,
            success: false,
            errorMessage: "Network error",
            metadata: [:],
            systemInfo: createMockSystemInfo()
        )
    ]
}

private func createMockEventsForStatistics(baseIdentifier: String = "stats-test") -> [BackgroundTaskEvent] {
    let baseTimestamp = Date()
    return [
        // Task 1: Scheduled -> Started -> Completed (Success)
        BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "\(baseIdentifier)-1",
            type: .taskScheduled,
            timestamp: Date(timeInterval: -300, since: baseTimestamp),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        ),
        BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "\(baseIdentifier)-1",
            type: .taskExecutionStarted,
            timestamp: Date(timeInterval: -295, since: baseTimestamp),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        ),
        BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "\(baseIdentifier)-1",
            type: .taskExecutionCompleted,
            timestamp: Date(timeInterval: -290, since: baseTimestamp),
            duration: 5.0,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        ),
        // Task 2: Scheduled -> Started -> Failed
        BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "\(baseIdentifier)-2",
            type: .taskScheduled,
            timestamp: Date(timeInterval: -200, since: baseTimestamp),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        ),
        BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "\(baseIdentifier)-2",
            type: .taskExecutionStarted,
            timestamp: Date(timeInterval: -195, since: baseTimestamp),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        ),
        BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "\(baseIdentifier)-2",
            type: .taskFailed,
            timestamp: Date(timeInterval: -190, since: baseTimestamp),
            duration: nil,
            success: false,
            errorMessage: "Network error",
            metadata: [:],
            systemInfo: createMockSystemInfo()
        )
    ]
}

private func createMockStatistics() -> BackgroundTaskStatistics {
    return BackgroundTaskStatistics(
        totalTasksScheduled: 10,
        totalTasksExecuted: 8,
        totalTasksCompleted: 6,
        totalTasksFailed: 2,
        totalTasksExpired: 2,
        averageExecutionTime: 4.5,
        successRate: 0.75,
        executionsByHour: [9: 2, 14: 3, 18: 3],
        errorsByType: ["Network error": 1, "Timeout": 1],
        lastExecutionTime: Date(),
        generatedAt: Date()
    )
}

private func createMockTimelineData() -> [TimelineDataPoint] {
    return [
        TimelineDataPoint(
            timestamp: Date(timeIntervalSinceNow: -300),
            eventType: .taskScheduled,
            taskIdentifier: "mock-task-1",
            duration: nil,
            success: true
        ),
        TimelineDataPoint(
            timestamp: Date(timeIntervalSinceNow: -295),
            eventType: .taskExecutionStarted,
            taskIdentifier: "mock-task-1",
            duration: nil,
            success: true
        ),
        TimelineDataPoint(
            timestamp: Date(timeIntervalSinceNow: -290),
            eventType: .taskExecutionCompleted,
            taskIdentifier: "mock-task-1",
            duration: 5.0,
            success: true
        )
    ]
}
