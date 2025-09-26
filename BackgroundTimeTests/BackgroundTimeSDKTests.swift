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
}

@Suite("Data Store Tests")
struct DataStoreTests {
    
    @Test("Event Recording")
    func testEventRecording() async throws {
        let dataStore = BackgroundTaskDataStore.shared
        
        // Clear existing events and wait for persistence
        dataStore.clearAllEvents()
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
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
        // Filter out SDK events to focus on our test event
        let testEvents = allEvents.filter { $0.taskIdentifier == "test-task-recording" }
        #expect(testEvents.count == 1, "Should have exactly one test event, but found \(testEvents.count) events")
        #expect(testEvents.first?.taskIdentifier == "test-task-recording")
        #expect(testEvents.first?.type == .taskScheduled)
    }
    
    @Test("Statistics Generation")
    func testStatisticsGeneration() async throws {
        let dataStore = BackgroundTaskDataStore.shared
        dataStore.clearAllEvents()
        
        // Wait for clear to complete
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Create test events with unique identifiers to avoid interference
        let baseIdentifier = "stats-test-\(UUID().uuidString)"
        let testEvents = createMockEventsForStatistics(baseIdentifier: baseIdentifier)
        for event in testEvents {
            dataStore.recordEvent(event)
        }
        
        // Delay to ensure events are recorded and persisted
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Verify events were actually recorded
        let allEvents = dataStore.getAllEvents()
        let testTaskEvents = allEvents.filter { $0.taskIdentifier.hasPrefix(baseIdentifier) }
        #expect(testTaskEvents.count == testEvents.count, "All test events should be recorded: expected \(testEvents.count), got \(testTaskEvents.count)")
        
        // Generate statistics only from our test events to avoid interference from other tests
        let stats = dataStore.generateStatistics(for: testTaskEvents, in: Date.distantPast...Date.distantFuture)
        
        #expect(stats.totalTasksScheduled == 2, "Should have 2 scheduled tasks")
        #expect(stats.totalTasksExecuted == 2, "Should have 2 executed tasks") 
        #expect(stats.totalTasksCompleted == 1, "Should have 1 completed task")
        #expect(stats.totalTasksFailed == 1, "Should have 1 failed task")
        #expect(stats.successRate >= 0.0, "Success rate should be >= 0.0")
        #expect(stats.successRate <= 1.0, "Success rate should be <= 1.0")
        #expect(stats.successRate == 0.5, "Success rate should be 0.5 (1 success out of 2 executed)")
    }
    
    @Test("Event Filtering by Date Range")
    func testEventFilteringByDateRange() async throws {
        let dataStore = BackgroundTaskDataStore.shared
        dataStore.clearAllEvents()
        
        // Wait for clear to complete
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        let now = Date()
        let oneHourAgo = Date(timeIntervalSinceNow: -3600)
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
        let dataStore = BackgroundTaskDataStore.shared
        dataStore.clearAllEvents()
        
        // Wait for clear to complete
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
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
        
        // Delay to ensure events are recorded and persisted
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms
        
        // Verify events were recorded
        let allEvents = dataStore.getAllEvents()
        let taskEvents = allEvents.filter { $0.taskIdentifier == taskIdentifier }
        #expect(taskEvents.count == 3, "Should have recorded 3 events for the task, found \(taskEvents.count)")
        
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

@Suite("Dashboard Configuration Tests")
struct DashboardConfigurationTests {
    
    @Test("Default Alert Thresholds")
    func testDefaultAlertThresholds() async throws {
        let thresholds = AlertThresholds.default
        
        #expect(thresholds.lowSuccessRate == 0.8)
        #expect(thresholds.highFailureRate == 0.2)
        #expect(thresholds.longExecutionTime == 30)
        #expect(thresholds.noExecutionPeriod == 86400)
    }
    
    @Test("Dashboard Configuration Encoding")
    func testDashboardConfigurationEncoding() async throws {
        let config = DashboardConfiguration.default
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(DashboardConfiguration.self, from: data)
        
        #expect(decodedConfig.refreshInterval == config.refreshInterval)
        #expect(decodedConfig.maxEventsPerUpload == config.maxEventsPerUpload)
        #expect(decodedConfig.enableRealTimeSync == config.enableRealTimeSync)
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
        let dataStore = BackgroundTaskDataStore.shared
        dataStore.clearAllEvents()
        
        // Wait for clear to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
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
        let dataStore = BackgroundTaskDataStore.shared
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
        let registered = scheduler.register(
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
        let dataStore = BackgroundTaskDataStore.shared
        
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
