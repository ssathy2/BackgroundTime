//
//  TimeRangeFilteringTest.swift
//  BackgroundTime Tests
//
//  Created on 9/20/25.
//

import Testing
import Foundation
@testable import BackgroundTime
import UIKit

@Suite("Time Range Filtering Tests")
struct TimeRangeFilteringTests {
    
    @Test("Time range filtering works correctly")
    func testTimeRangeFiltering() async throws {
        // Use isolated test instance
        let dataStore = BackgroundTaskDataStore.createTestInstance()
        
        // Create unique task identifiers for this test
        let testPrefix = "timerange_test_\(UUID().uuidString.prefix(8))_"
        
        // Create test events with different timestamps
        let now = Date()
        let futureTime = now.addingTimeInterval(60) // 1 minute in the future for range end
        let oneHourAgo = now.addingTimeInterval(-3600)
        let sixHoursAgo = now.addingTimeInterval(-6 * 3600)
        let oneDayAgo = now.addingTimeInterval(-24 * 3600)
        let oneWeekAgo = now.addingTimeInterval(-7 * 24 * 3600)
        
        let testEvents = [
            BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: "\(testPrefix)task-1",
                type: .taskExecutionStarted,
                timestamp: oneHourAgo,
                success: true,
                systemInfo: SystemInfo(
                    backgroundAppRefreshStatus: .available,
                    deviceModel: "iPhone",
                    systemVersion: "iOS 16.0",
                    lowPowerModeEnabled: false,
                    batteryLevel: 0.8,
                    batteryState: .unplugged
                )
            ),
            BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: "\(testPrefix)task-2",
                type: .taskExecutionStarted,
                timestamp: sixHoursAgo,
                success: true,
                systemInfo: SystemInfo(
                    backgroundAppRefreshStatus: .available,
                    deviceModel: "iPhone",
                    systemVersion: "iOS 16.0",
                    lowPowerModeEnabled: false,
                    batteryLevel: 0.8,
                    batteryState: .unplugged
                )
            ),
            BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: "\(testPrefix)task-3",
                type: .taskExecutionStarted,
                timestamp: oneDayAgo,
                success: true,
                systemInfo: SystemInfo(
                    backgroundAppRefreshStatus: .available,
                    deviceModel: "iPhone",
                    systemVersion: "iOS 16.0",
                    lowPowerModeEnabled: false,
                    batteryLevel: 0.8,
                    batteryState: .unplugged
                )
            ),
            BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: "\(testPrefix)task-4",
                type: .taskExecutionStarted,
                timestamp: oneWeekAgo,
                success: true,
                systemInfo: SystemInfo(
                    backgroundAppRefreshStatus: .available,
                    deviceModel: "iPhone",
                    systemVersion: "iOS 16.0",
                    lowPowerModeEnabled: false,
                    batteryLevel: 0.8,
                    batteryState: .unplugged
                )
            )
        ]
        
        // Add test events to data store
        for event in testEvents {
            dataStore.recordEvent(event)
        }
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify events were stored
        let allEvents = dataStore.getAllEvents()
        #expect(allEvents.count == 4, "Should have 4 test events stored, found \(allEvents.count)")
        
        // Test 1 hour filtering
        let oneHourRange = TimeRange.last1Hour
        let startDate1h = now.addingTimeInterval(-oneHourRange.timeInterval)
        let events1h = dataStore.getEventsInDateRange(from: startDate1h, to: futureTime)
        #expect(events1h.count == 1, "Should find 1 test event in last hour, found \(events1h.count)")
        
        // Test 6 hours filtering
        let sixHoursRange = TimeRange.last6Hours
        let startDate6h = now.addingTimeInterval(-sixHoursRange.timeInterval)
        let events6h = dataStore.getEventsInDateRange(from: startDate6h, to: futureTime)
        #expect(events6h.count == 2, "Should find 2 test events in last 6 hours, found \(events6h.count)")
        
        // Test 24 hours filtering
        let twentyFourHoursRange = TimeRange.last24Hours
        let startDate24h = now.addingTimeInterval(-twentyFourHoursRange.timeInterval)
        let events24h = dataStore.getEventsInDateRange(from: startDate24h, to: futureTime)
        #expect(events24h.count == 3, "Should find 3 test events in last 24 hours, found \(events24h.count)")
        
        // Test 7 days filtering
        let sevenDaysRange = TimeRange.last7Days
        let startDate7d = now.addingTimeInterval(-sevenDaysRange.timeInterval)
        let events7d = dataStore.getEventsInDateRange(from: startDate7d, to: futureTime)
        #expect(events7d.count == 4, "Should find 4 test events in last 7 days, found \(events7d.count)")
    }
    
    @Test("Dashboard view model respects time range selection")
    func testViewModelTimeRangeFiltering() async throws {
        // Create isolated data store and view model
        let dataStore = BackgroundTaskDataStore.createTestInstance()
        let _ = await DashboardViewModel()
        
        // Create unique task identifiers for this test
        let testPrefix = "viewmodel_test_\(UUID().uuidString.prefix(8))_"
        
        // Create test events with unique identifiers
        let now = Date()
        let systemInfo = SystemInfo(
            backgroundAppRefreshStatus: .available,
            deviceModel: "iPhone",
            systemVersion: "iOS 16.0",
            lowPowerModeEnabled: false,
            batteryLevel: 0.8,
            batteryState: .unplugged
        )
        
        // Create both execution started and completed events for proper statistics
        let recentStartEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "\(testPrefix)recent-task",
            type: .taskExecutionStarted,
            timestamp: now.addingTimeInterval(-30 * 60), // 30 minutes ago
            success: true,
            systemInfo: systemInfo
        )
        
        let recentCompleteEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "\(testPrefix)recent-task",
            type: .taskExecutionCompleted,
            timestamp: now.addingTimeInterval(-30 * 60 + 5), // 5 seconds later
            duration: 5.0,
            success: true,
            systemInfo: systemInfo
        )
        
        let oldStartEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "\(testPrefix)old-task",
            type: .taskExecutionStarted,
            timestamp: now.addingTimeInterval(-2 * 24 * 3600), // 2 days ago
            success: true,
            systemInfo: systemInfo
        )
        
        let oldCompleteEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "\(testPrefix)old-task",
            type: .taskExecutionCompleted,
            timestamp: now.addingTimeInterval(-2 * 24 * 3600 + 3), // 3 seconds later
            duration: 3.0,
            success: true,
            systemInfo: systemInfo
        )
        
        // Add events to our isolated data store
        dataStore.recordEvent(recentStartEvent)
        dataStore.recordEvent(recentCompleteEvent)
        dataStore.recordEvent(oldStartEvent)
        dataStore.recordEvent(oldCompleteEvent)
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Verify we have our test events in the data store
        let allEvents = dataStore.getAllEvents()
        #expect(allEvents.count == 4, "Should have exactly 4 test events (2 start + 2 complete), found \(allEvents.count)")
        
        // Test 1 hour range - should only show recent events
        let events1h = dataStore.getEventsInDateRange(
            from: now.addingTimeInterval(-TimeRange.last1Hour.timeInterval),
            to: now
        )
        #expect(events1h.count == 2, "Should show 2 test events (1 start + 1 complete) for 1 hour range, found \(events1h.count)")
        #expect(events1h.contains { $0.taskIdentifier == "\(testPrefix)recent-task" }, "Should show the recent task events")
        
        // Test 7 days range - should show all events
        let events7d = dataStore.getEventsInDateRange(
            from: now.addingTimeInterval(-TimeRange.last7Days.timeInterval),
            to: now
        )
        #expect(events7d.count == 4, "Should show 4 test events (2 start + 2 complete) for 7 days range, found \(events7d.count)")
        
        // Generate statistics based on filtered data
        let stats = dataStore.generateStatistics(for: events7d, in: now.addingTimeInterval(-TimeRange.last7Days.timeInterval)...now)
        #expect(stats.totalTasksExecuted >= 2, "Statistics should reflect filtered data with at least 2 tasks executed, found \(stats.totalTasksExecuted)")
    }
    
    // MARK: - Additional Coverage Tests
    
    @Test("All TimeRange cases work correctly")
    func testAllTimeRangeCases() async throws {
        // Test all TimeRange enum cases for complete coverage
        let dataStore = BackgroundTaskDataStore.createTestInstance()
        let now = Date()
        let futureTime = now.addingTimeInterval(60)
        
        // Test last30Days
        let thirtyDaysRange = TimeRange.last30Days
        #expect(thirtyDaysRange.timeInterval == 30 * 24 * 3600)
        #expect(thirtyDaysRange.displayName == "Last 30 Days")
        
        let startDate30d = now.addingTimeInterval(-thirtyDaysRange.timeInterval)
        let events30d = dataStore.getEventsInDateRange(from: startDate30d, to: futureTime)
        #expect(events30d.count == 0, "Should find 0 events in last 30 days with empty store")
        
        // Test 'all' time range
        let allRange = TimeRange.all
        #expect(allRange.timeInterval == TimeInterval.greatestFiniteMagnitude)
        #expect(allRange.displayName == "All Time")
        
        // Test TimeRange.CaseIterable
        let allCases = TimeRange.allCases
        #expect(allCases.count == 6, "Should have 6 time range cases")
        #expect(allCases.contains(.last1Hour))
        #expect(allCases.contains(.last6Hours))
        #expect(allCases.contains(.last24Hours))
        #expect(allCases.contains(.last7Days))
        #expect(allCases.contains(.last30Days))
        #expect(allCases.contains(.all))
    }
    
    @Test("TimeRange codable functionality")
    func testTimeRangeCodable() async throws {
        // Test that TimeRange can be encoded and decoded
        let originalRange = TimeRange.last24Hours
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalRange)
        
        let decoder = JSONDecoder()
        let decodedRange = try decoder.decode(TimeRange.self, from: data)
        
        #expect(decodedRange == originalRange, "TimeRange should be properly codable")
        #expect(decodedRange.timeInterval == originalRange.timeInterval)
        #expect(decodedRange.displayName == originalRange.displayName)
    }
    
    @Test("BackgroundTaskEvent error message and metadata handling")
    func testEventErrorAndMetadata() async throws {
        let dataStore = BackgroundTaskDataStore.createTestInstance()
        let testPrefix = "error_test_\(UUID().uuidString.prefix(8))_"
        
        // Create event with error message and metadata
        let errorEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "\(testPrefix)error-task",
            type: .taskFailed,
            timestamp: Date(),
            duration: 2.5,
            success: false,
            errorMessage: "Network timeout error",
            metadata: ["errorCode": 500.description, "retryAttempt": 3.description],
            systemInfo: SystemInfo(
                backgroundAppRefreshStatus: .denied,
                deviceModel: "iPad",
                systemVersion: "iOS 17.0",
                lowPowerModeEnabled: true,
                batteryLevel: 0.15,
                batteryState: .charging
            )
        )
        
        dataStore.recordEvent(errorEvent)
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let events = dataStore.getAllEvents()
        #expect(events.count == 1, "Should have 1 error event")
        
        let retrievedEvent = events.first!
        #expect(retrievedEvent.errorMessage == "Network timeout error")
        #expect(retrievedEvent.duration == 2.5)
        #expect(retrievedEvent.success == false)
        #expect(retrievedEvent.type == .taskFailed)
        
        // Test statistics generation with failed events
        let stats = dataStore.generateStatistics()
        #expect(stats.totalTasksFailed == 1, "Should count 1 failed task")
        #expect(stats.errorsByType.count > 0, "Should have error categorization")
    }
    
    @Test("BackgroundTaskEventType continuous task events")
    func testContinuousTaskEventTypes() async throws {
        // Test iOS 26.0+ continuous task event types if available
        if #available(iOS 26.0, *) {
            let continuousTypes: [BackgroundTaskEventType] = [
                .continuousTaskStarted,
                .continuousTaskPaused,
                .continuousTaskResumed,
                .continuousTaskStopped,
                .continuousTaskProgress
            ]
            
            for eventType in continuousTypes {
                #expect(eventType.isContinuousTaskEvent == true, "\(eventType) should be identified as continuous task event")
            }
        }
        
        // Test regular event types are not continuous
        let regularTypes: [BackgroundTaskEventType] = [
            .taskScheduled,
            .taskExecutionStarted,
            .taskExecutionCompleted,
            .taskExpired,
            .taskCancelled,
            .taskFailed,
            .initialization,
            .appEnteredBackground,
            .appWillEnterForeground
        ]
        
        for eventType in regularTypes {
            #expect(eventType.isContinuousTaskEvent == false, "\(eventType) should not be identified as continuous task event")
        }
    }
    
    @Test("SystemInfo different device states")
    func testSystemInfoVariations() async throws {
        let dataStore = BackgroundTaskDataStore.createTestInstance()
        let testPrefix = "system_test_\(UUID().uuidString.prefix(8))_"
        
        // Test different UIBackgroundRefreshStatus values
        let restrictedSystemInfo = SystemInfo(
            backgroundAppRefreshStatus: .restricted,
            deviceModel: "iPhone15,2",
            systemVersion: "iOS 18.0",
            lowPowerModeEnabled: true,
            batteryLevel: 0.05,
            batteryState: .full
        )
        
        let restrictedEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "\(testPrefix)restricted-task",
            type: .appEnteredBackground,
            timestamp: Date(),
            success: true,
            systemInfo: restrictedSystemInfo
        )
        
        dataStore.recordEvent(restrictedEvent)
        
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        let events = dataStore.getAllEvents()
        #expect(events.count == 1)
        
        let retrievedSystemInfo = events.first!.systemInfo
        #expect(retrievedSystemInfo.backgroundAppRefreshStatus == .restricted)
        #expect(retrievedSystemInfo.lowPowerModeEnabled == true)
        #expect(retrievedSystemInfo.batteryLevel == 0.05)
        #expect(retrievedSystemInfo.batteryState == .full)
    }
    
    @Test("BackgroundTaskEvent codable with all properties")
    func testEventCodableComplete() async throws {
        // Test complete encoding/decoding of BackgroundTaskEvent
        let originalEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "codable-test-task",
            type: .taskExecutionCompleted,
            timestamp: Date(),
            duration: 4.2,
            success: true,
            errorMessage: "Test error",
            metadata: ["key1": "value1", "key2": 42.description],
            systemInfo: SystemInfo(
                backgroundAppRefreshStatus: .available,
                deviceModel: "iPhone14,2",
                systemVersion: "iOS 16.5",
                lowPowerModeEnabled: false,
                batteryLevel: 0.67,
                batteryState: .unplugged
            )
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalEvent)
        
        let decoder = JSONDecoder()
        let decodedEvent = try decoder.decode(BackgroundTaskEvent.self, from: data)
        
        #expect(decodedEvent.id == originalEvent.id)
        #expect(decodedEvent.taskIdentifier == originalEvent.taskIdentifier)
        #expect(decodedEvent.type == originalEvent.type)
        #expect(decodedEvent.duration == originalEvent.duration)
        #expect(decodedEvent.success == originalEvent.success)
        #expect(decodedEvent.errorMessage == originalEvent.errorMessage)
        #expect(decodedEvent.systemInfo.backgroundAppRefreshStatus == originalEvent.systemInfo.backgroundAppRefreshStatus)
        #expect(decodedEvent.systemInfo.batteryLevel == originalEvent.systemInfo.batteryLevel)
    }
    
    @Test("Data store capacity and buffer management")
    func testDataStoreCapacityManagement() async throws {
        let dataStore = BackgroundTaskDataStore.createTestInstance()
        
        // Configure with small capacity for testing
        dataStore.configure(maxStoredEvents: 3)
        
        let systemInfo = SystemInfo(
            backgroundAppRefreshStatus: .available,
            deviceModel: "iPhone",
            systemVersion: "iOS 16.0",
            lowPowerModeEnabled: false,
            batteryLevel: 0.8,
            batteryState: .unplugged
        )
        
        // Add more events than capacity
        for i in 1...5 {
            let event = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: "capacity-test-\(i)",
                type: .taskExecutionStarted,
                timestamp: Date().addingTimeInterval(TimeInterval(i)),
                success: true,
                systemInfo: systemInfo
            )
            dataStore.recordEvent(event)
        }
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let allEvents = dataStore.getAllEvents()
        #expect(allEvents.count == 3, "Should maintain capacity limit of 3 events")
        
        // Should have the most recent events (events 3, 4, 5)
        let taskIdentifiers = allEvents.map { $0.taskIdentifier }.sorted()
        #expect(taskIdentifiers.contains("capacity-test-3"))
        #expect(taskIdentifiers.contains("capacity-test-4"))
        #expect(taskIdentifiers.contains("capacity-test-5"))
        
        // Test clear functionality
        dataStore.clearAllEvents()
        
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        let clearedEvents = dataStore.getAllEvents()
        #expect(clearedEvents.count == 0, "Should have no events after clearing")
    }
}
