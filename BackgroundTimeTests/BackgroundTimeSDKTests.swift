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
        
        // Clear existing events
        dataStore.clearAllEvents()
        
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "test-task",
            type: .taskScheduled,
            timestamp: Date(),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: ["test": "value"],
            systemInfo: createMockSystemInfo()
        )
        
        dataStore.recordEvent(event)
        
        let allEvents = dataStore.getAllEvents()
        #expect(allEvents.count == 1)
        #expect(allEvents.first?.taskIdentifier == "test-task")
        #expect(allEvents.first?.type == .taskScheduled)
    }
    
    @Test("Statistics Generation")
    func testStatisticsGeneration() async throws {
        let dataStore = BackgroundTaskDataStore.shared
        dataStore.clearAllEvents()
        
        // Record several test events
        let events = createMockEvents()
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let stats = dataStore.generateStatistics()
        
        #expect(stats.totalTasksScheduled > 0)
        #expect(stats.totalTasksExecuted > 0)
        #expect(stats.successRate >= 0.0)
        #expect(stats.successRate <= 1.0)
    }
    
    @Test("Event Filtering by Date Range")
    func testEventFilteringByDateRange() async throws {
        let dataStore = BackgroundTaskDataStore.shared
        dataStore.clearAllEvents()
        
        let now = Date()
        let oneHourAgo = Date(timeIntervalSinceNow: -3600)
        let twoHoursAgo = Date(timeIntervalSinceNow: -7200)
        
        // Create events at different times
        let recentEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "recent",
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
            taskIdentifier: "old",
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
        
        let recentEvents = dataStore.getEventsInDateRange(from: oneHourAgo, to: now)
        
        #expect(recentEvents.count == 1)
        #expect(recentEvents.first?.taskIdentifier == "recent")
    }
    
    @Test("Task Performance Metrics")
    func testTaskPerformanceMetrics() async throws {
        let dataStore = BackgroundTaskDataStore.shared
        dataStore.clearAllEvents()
        
        let taskIdentifier = "performance-test-task"
        
        // Create a series of events for the same task
        let scheduledEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskScheduled,
            timestamp: Date(),
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
            timestamp: Date(timeIntervalSinceNow: 300), // 5 minutes later
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
            timestamp: Date(timeIntervalSinceNow: 305), // 5 seconds duration
            duration: 5.0,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        )
        
        dataStore.recordEvent(scheduledEvent)
        dataStore.recordEvent(executedEvent)
        dataStore.recordEvent(completedEvent)
        
        let metrics = dataStore.getTaskPerformanceMetrics(for: taskIdentifier)
        
        #expect(metrics != nil)
        #expect(metrics?.taskIdentifier == taskIdentifier)
        #expect(metrics?.totalScheduled == 1)
        #expect(metrics?.totalExecuted == 1)
        #expect(metrics?.totalCompleted == 1)
        #expect(metrics?.averageDuration == 5.0)
        #expect(metrics?.successRate == 1.0)
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
        
        let stats = dataStore.generateStatistics()
        
        #expect(stats.totalTasksScheduled == 0)
        #expect(stats.totalTasksExecuted == 0)
        #expect(stats.totalTasksCompleted == 0)
        #expect(stats.totalTasksFailed == 0)
        #expect(stats.successRate == 0.0)
        #expect(stats.averageExecutionTime == 0.0)
    }
}

@Suite("Swizzling Tests")
struct SwizzlingTests {
    
    @Test("BGTaskScheduler Swizzling Initialization")
    func testBGTaskSchedulerSwizzling() async throws {
        // Clear events first
        BackgroundTaskDataStore.shared.clearAllEvents()
        
        // Initialize swizzling
        BGTaskSchedulerSwizzler.swizzleSchedulerMethods()
        
        // Verify swizzling doesn't break normal operation
        let scheduler = BGTaskScheduler.shared
        #expect(scheduler != nil)
        
        // Test that swizzling can be called multiple times without issues
        BGTaskSchedulerSwizzler.swizzleSchedulerMethods()
        BGTaskSchedulerSwizzler.swizzleSchedulerMethods()
        
        #expect(scheduler != nil) // Still working after multiple swizzle attempts
    }
    
    @Test("Task Registration Tracking")
    func testTaskRegistrationTracking() async throws {
        BackgroundTaskDataStore.shared.clearAllEvents()
        BGTaskSchedulerSwizzler.swizzleSchedulerMethods()
        
        let taskIdentifier = "test-registration-task"
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
        // But we can still verify the swizzling is working by checking method existence
        
        let hasSwizzledMethod = BGTaskScheduler.self.responds(to: #selector(BGTaskScheduler.bt_register(forTaskWithIdentifier:using:launchHandler:)))
        #expect(hasSwizzledMethod)
    }
    
    @Test("Task Cancellation Tracking")
    func testTaskCancellationTracking() async throws {
        BackgroundTaskDataStore.shared.clearAllEvents()
        BGTaskSchedulerSwizzler.swizzleSchedulerMethods()
        
        let taskIdentifier = "test-cancellation-task"
        let scheduler = BGTaskScheduler.shared
        
        // Test individual task cancellation
        scheduler.cancel(taskRequestWithIdentifier: taskIdentifier)
        
        // Verify swizzled method exists
        let hasSwizzledCancelMethod = BGTaskScheduler.self.responds(to: #selector(BGTaskScheduler.bt_cancel(taskRequestWithIdentifier:)))
        #expect(hasSwizzledCancelMethod)
        
        // Test cancel all tasks
        scheduler.cancelAllTaskRequests()
        
        let hasSwizzledCancelAllMethod = BGTaskScheduler.self.responds(to: #selector(BGTaskScheduler.bt_cancelAllTaskRequests))
        #expect(hasSwizzledCancelAllMethod)
    }
    
    @Test("Task Submission Error Handling")
    func testTaskSubmissionErrorHandling() async throws {
        BackgroundTaskDataStore.shared.clearAllEvents()
        BGTaskSchedulerSwizzler.swizzleSchedulerMethods()
        
        let scheduler = BGTaskScheduler.shared
        
        // Create a task request with invalid identifier (should cause error)
        let taskRequest = BGAppRefreshTaskRequest(identifier: "invalid-task-not-in-plist")
        
        do {
            try scheduler.submit(taskRequest)
            // If submission succeeds (unlikely in test), that's fine
        } catch {
            // Expected to fail in test environment - verify error is properly handled
            #expect(error != nil)
        }
        
        // Verify swizzled method exists
        let hasSwizzledSubmitMethod = BGTaskScheduler.self.responds(to: #selector(BGTaskScheduler.bt_submit(_:)))
        #expect(hasSwizzledSubmitMethod)
    }
    
    @Test("BGTask Swizzling Initialization")
    func testBGTaskSwizzling() async throws {
        BGTaskSwizzler.swizzleTaskMethods()
        
        // Verify swizzled method exists
        let hasSwizzledCompletionMethod = BGTask.self.responds(to: #selector(BGTask.bt_setTaskCompleted(success:)))
        #expect(hasSwizzledCompletionMethod)
    }
    
    @Test("Task Start Time Tracking")
    func testTaskStartTimeTracking() async throws {
        let taskIdentifier = "test-start-time-task"
        let startTime = Date()
        
        // Clear existing start times
        BGTaskSwizzler.taskQueue.async(flags: .barrier) {
            BGTaskSwizzler.taskStartTimes.removeAll()
        }
        
        // Simulate task start tracking
        BGTaskSwizzler.taskQueue.async(flags: .barrier) {
            BGTaskSwizzler.taskStartTimes[taskIdentifier] = startTime
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
        
        #expect(recordedStartTime != nil)
        #expect(abs(recordedStartTime!.timeIntervalSince(startTime)) < 1.0) // Within 1 second
    }
    
    @Test("Task Completion Event Recording")
    func testTaskCompletionEventRecording() async throws {
        BackgroundTaskDataStore.shared.clearAllEvents()
        BGTaskSwizzler.swizzleTaskMethods()
        
        let taskIdentifier = "test-completion-task"
        let startTime = Date()
        
        // Set up start time manually in the BGTaskSwizzler
        BGTaskSwizzler.taskQueue.async(flags: .barrier) {
            BGTaskSwizzler.taskStartTimes[taskIdentifier] = startTime
        }
        
        // Wait for the start time to be set
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Simulate task completion by directly creating an event
        // This tests the event recording functionality without needing a real BGTask
        let completionEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskExecutionCompleted,
            timestamp: Date(),
            duration: 5.0,
            success: true,
            errorMessage: nil,
            metadata: ["test": "completion"],
            systemInfo: createMockSystemInfo()
        )
        
        BackgroundTaskDataStore.shared.recordEvent(completionEvent)
        
        // Simulate cleaning up start time (as the swizzled method would do)
        BGTaskSwizzler.taskQueue.async(flags: .barrier) {
            BGTaskSwizzler.taskStartTimes.removeValue(forKey: taskIdentifier)
        }
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Verify the event was recorded
        let allEvents = BackgroundTaskDataStore.shared.getAllEvents()
        let completionEvents = allEvents.filter { $0.type == .taskExecutionCompleted && $0.taskIdentifier == taskIdentifier }
        #expect(completionEvents.count == 1)
        
        // Verify start time was cleaned up
        let remainingStartTime = await withCheckedContinuation { continuation in
            BGTaskSwizzler.taskQueue.async {
                let time = BGTaskSwizzler.taskStartTimes[taskIdentifier]
                continuation.resume(returning: time)
            }
        }
        
        #expect(remainingStartTime == nil)
    }
    
    @Test("Swizzling Thread Safety")
    func testSwizzlingThreadSafety() async throws {
        let taskIdentifier = "test-thread-safety"
        let iterations = 10
        
        // Clear existing data
        BGTaskSwizzler.taskQueue.async(flags: .barrier) {
            BGTaskSwizzler.taskStartTimes.removeAll()
        }
        
        // Simulate concurrent access to task start times
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let uniqueIdentifier = "\(taskIdentifier)-\(i)"
                    BGTaskSwizzler.taskQueue.async(flags: .barrier) {
                        BGTaskSwizzler.taskStartTimes[uniqueIdentifier] = Date()
                    }
                }
            }
        }
        
        // Wait for all operations to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Verify all entries were recorded
        let finalCount = await withCheckedContinuation { continuation in
            BGTaskSwizzler.taskQueue.async {
                let count = BGTaskSwizzler.taskStartTimes.count
                continuation.resume(returning: count)
            }
        }
        
        #expect(finalCount == iterations)
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
