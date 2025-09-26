//
//  DataStoreTests.swift
//  BackgroundTimeTests
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Testing
import Foundation
import UIKit
import BackgroundTasks
@testable import BackgroundTime

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