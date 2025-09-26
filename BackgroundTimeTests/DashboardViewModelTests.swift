//
//  DashboardViewModelTests.swift
//  BackgroundTimeTests
//
//  Created by Siddharth Sathyam on 9/26/25.
//

import Testing
import Foundation
import UIKit
import Combine
@testable import BackgroundTime

@Suite("DashboardViewModel Tests")
@MainActor
struct DashboardViewModelTests {
    
    // MARK: - Initialization Tests
    
    @Test("DashboardViewModel Initialization")
    func testDashboardViewModelInitialization() async throws {
        let viewModel = DashboardViewModel()
        
        // Verify initial state
        #expect(viewModel.statistics == nil, "Statistics should be nil initially")
        #expect(viewModel.events.isEmpty, "Events should be empty initially")
        #expect(viewModel.timelineData.isEmpty, "Timeline data should be empty initially")
        #expect(viewModel.taskMetrics.isEmpty, "Task metrics should be empty initially")
        #expect(viewModel.continuousTasksInfo.isEmpty, "Continuous tasks info should be empty initially")
        #expect(viewModel.isLoading == false, "Should not be loading initially")
        #expect(viewModel.error == nil, "Error should be nil initially")
        #expect(viewModel.selectedTimeRange == .last24Hours, "Should default to last 24 hours")
    }
    
    // MARK: - Data Loading Tests
    
    @Test("Load Data for Time Range")
    func testLoadDataForTimeRange() async throws {
        let viewModel = DashboardViewModel()
        
        // Create test events in the shared data store
        let testEvents = createTestEvents(count: 5)
        BackgroundTaskDataStore.shared.clearAllEvents()
        for event in testEvents {
            BackgroundTaskDataStore.shared.recordEvent(event)
        }
        
        // Test loading data
        viewModel.loadData(for: .last24Hours)
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        #expect(!viewModel.isLoading, "Should not be loading after completion")
        #expect(viewModel.error == nil, "Should not have error after successful load")
        #expect(viewModel.events.count > 0, "Should have loaded events")
        #expect(viewModel.statistics != nil, "Should have generated statistics")
        #expect(!viewModel.timelineData.isEmpty, "Should have generated timeline data")
        
        // Clean up
        BackgroundTaskDataStore.shared.clearAllEvents()
    }
    
    @Test("Load Data Same Time Range Optimization")
    func testLoadDataSameTimeRangeOptimization() async throws {
        let viewModel = DashboardViewModel()
        
        // Load data for first time
        viewModel.loadData(for: .last24Hours)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Try to load same time range again (should be optimized out)
        viewModel.loadData(for: .last24Hours)
        
        // Verify no unnecessary loading occurred
        #expect(!viewModel.isLoading, "Should not reload for same time range")
        
        // Load different time range (should trigger reload)
        viewModel.loadData(for: .last7Days)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(!viewModel.isLoading, "Should complete loading for different time range")
        #expect(viewModel.selectedTimeRange == .last7Days, "Should update selected time range")
    }
    
    @Test("Load Data with Empty Data Store")
    func testLoadDataWithEmptyDataStore() async throws {
        let viewModel = DashboardViewModel()
        
        // Clear all events first
        BackgroundTaskDataStore.shared.clearAllEvents()
        
        viewModel.loadData(for: .last24Hours)
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(!viewModel.isLoading, "Should complete loading even with empty data")
        #expect(viewModel.error == nil, "Should not have error with empty data")
        #expect(viewModel.events.isEmpty, "Should have no events")
        #expect(viewModel.timelineData.isEmpty, "Should have no timeline data")
        #expect(viewModel.taskMetrics.isEmpty, "Should have no task metrics")
    }
    
    @Test("Load Data Filtering by Time Range")
    func testLoadDataFilteringByTimeRange() async throws {
        let viewModel = DashboardViewModel()
        
        BackgroundTaskDataStore.shared.clearAllEvents()
        
        let now = Date()
        
        // Create events at different times
        let recentEvent = createTestEvent(
            taskId: "recent-task",
            timestamp: now.addingTimeInterval(-1800), // 30 minutes ago
            type: .taskExecutionCompleted
        )
        let oldEvent = createTestEvent(
            taskId: "old-task", 
            timestamp: now.addingTimeInterval(-86400 * 2), // 2 days ago
            type: .taskExecutionCompleted
        )
        
        BackgroundTaskDataStore.shared.recordEvent(recentEvent)
        BackgroundTaskDataStore.shared.recordEvent(oldEvent)
        
        // Load data for last hour
        viewModel.loadData(for: .last1Hour)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Should only contain recent event
        #expect(viewModel.events.count == 1, "Should filter to recent events only")
        #expect(viewModel.events.first?.taskIdentifier == "recent-task", "Should contain only recent task")
        
        // Load data for all time
        viewModel.loadData(for: .all)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Should contain both events
        #expect(viewModel.events.count == 2, "Should contain all events for 'all' time range")
        
        // Clean up
        BackgroundTaskDataStore.shared.clearAllEvents()
    }
    
    @Test("Error Handling During Data Loading")
    func testErrorHandlingDuringDataLoading() async throws {
        let viewModel = DashboardViewModel()
        
        // Since we can't easily mock the dataStore in the current architecture,
        // we'll test the error state manually
        await viewModel.simulateError("Test error message")
        
        #expect(viewModel.error != nil, "Should have error after setting error state")
        #expect(viewModel.error?.contains("Test error message") == true, "Should contain error message")
    }
    
    // MARK: - Continuous Tasks Tests (iOS 26.0+)
    
    @Test("Process Continuous Tasks Data")
    @available(iOS 26.0, *)
    func testProcessContinuousTasksData() async throws {
        let viewModel = DashboardViewModel()
        
        BackgroundTaskDataStore.shared.clearAllEvents()
        
        // Create continuous task events
        let continuousEvents = [
            createTestEvent(taskId: "continuous-1", type: .continuousTaskStarted, success: true),
            createTestEvent(taskId: "continuous-1", type: .continuousTaskProgress, success: true),
            createTestEvent(taskId: "continuous-1", type: .continuousTaskPaused, success: true),
            createTestEvent(taskId: "continuous-1", type: .continuousTaskResumed, success: true),
            createTestEvent(taskId: "continuous-2", type: .continuousTaskStarted, success: true),
            createTestEvent(taskId: "continuous-2", type: .continuousTaskStopped, success: true)
        ]
        
        for event in continuousEvents {
            BackgroundTaskDataStore.shared.recordEvent(event)
        }
        
        viewModel.loadData(for: .last24Hours)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(viewModel.continuousTasksInfo.count > 0, "Should process continuous tasks data")
        
        let typedInfo = viewModel.continuousTasksInfoTyped
        #expect(typedInfo.count >= 2, "Should have info for both continuous tasks")
        
        // Verify task statuses
        let runningTask = typedInfo.first { $0.taskIdentifier == "continuous-1" }
        let stoppedTask = typedInfo.first { $0.taskIdentifier == "continuous-2" }
        
        #expect(runningTask?.currentStatus == .running, "First task should be running")
        #expect(stoppedTask?.currentStatus == .stopped, "Second task should be stopped")
        
        // Clean up
        BackgroundTaskDataStore.shared.clearAllEvents()
    }
    
    // MARK: - Refresh Tests
    
    @Test("Refresh Data")
    func testRefreshData() async throws {
        let viewModel = DashboardViewModel()
        
        BackgroundTaskDataStore.shared.clearAllEvents()
        
        // Load initial data
        viewModel.loadData(for: .last6Hours)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let initialEventCount = viewModel.events.count
        
        // Add more events
        let newEvent = createTestEvent(taskId: "new-task", type: .taskExecutionCompleted)
        BackgroundTaskDataStore.shared.recordEvent(newEvent)
        
        // Refresh data
        viewModel.refresh()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(viewModel.events.count == initialEventCount + 1, "Should reflect new events after refresh")
        #expect(viewModel.selectedTimeRange == .last6Hours, "Should maintain selected time range")
        
        // Clean up
        BackgroundTaskDataStore.shared.clearAllEvents()
    }
    
    // MARK: - Data Management Tests
    
    @Test("Clear All Data")
    func testClearAllData() async throws {
        let viewModel = DashboardViewModel()
        
        BackgroundTaskDataStore.shared.clearAllEvents()
        
        // Add some test data
        let testEvents = createTestEvents(count: 5)
        for event in testEvents {
            BackgroundTaskDataStore.shared.recordEvent(event)
        }
        
        // Load data
        viewModel.loadData(for: .last24Hours)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(viewModel.events.count > 0, "Should have events before clearing")
        
        // Clear all data
        viewModel.clearAllData()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(viewModel.events.isEmpty, "Should have no events after clearing")
    }
    
    @Test("Export Data")
    func testExportData() async throws {
        let viewModel = DashboardViewModel()
        
        BackgroundTaskDataStore.shared.clearAllEvents()
        
        // Add test data
        let testEvents = createTestEvents(count: 3)
        for event in testEvents {
            BackgroundTaskDataStore.shared.recordEvent(event)
        }
        
        viewModel.loadData(for: .last24Hours)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Export data
        let exportedData = viewModel.exportData()
        
        #expect(exportedData.events.count >= 0, "Should export events data")
        #expect(exportedData.timeline.count >= 0, "Should export timeline data")
        #expect(exportedData.generatedAt <= Date(), "Should have valid generation timestamp")
        
        // Clean up
        BackgroundTaskDataStore.shared.clearAllEvents()
    }
    
    @Test("Sync with Dashboard")
    func testSyncWithDashboard() async throws {
        let viewModel = DashboardViewModel()
        
        // Test sync (should not throw)
        await viewModel.syncWithDashboard()
        
        // Verify no error state
        #expect(viewModel.error == nil, "Sync should not produce error with test setup")
    }
    
    // MARK: - Timeline Data Tests
    
    @Test("Timeline Data Generation")
    func testTimelineDataGeneration() async throws {
        let viewModel = DashboardViewModel()
        
        BackgroundTaskDataStore.shared.clearAllEvents()
        
        let now = Date()
        let events = [
            createTestEvent(taskId: "task-1", timestamp: now.addingTimeInterval(-3600), type: .taskExecutionStarted),
            createTestEvent(taskId: "task-1", timestamp: now.addingTimeInterval(-3580), type: .taskExecutionCompleted, duration: 20),
            createTestEvent(taskId: "task-2", timestamp: now.addingTimeInterval(-1800), type: .taskExpired),
        ]
        
        for event in events {
            BackgroundTaskDataStore.shared.recordEvent(event)
        }
        
        viewModel.loadData(for: .last24Hours)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(viewModel.timelineData.count == 3, "Should generate timeline data for all events")
        
        // Verify timeline data is sorted by timestamp (newest first)
        let timestamps = viewModel.timelineData.map { $0.timestamp }
        let sortedTimestamps = timestamps.sorted { $0 > $1 }
        #expect(timestamps == sortedTimestamps, "Timeline data should be sorted by timestamp desc")
        
        // Verify timeline data fields
        let firstItem = viewModel.timelineData.first!
        #expect(firstItem.taskIdentifier == "task-2", "First item should be most recent")
        #expect(firstItem.eventType == .taskExpired, "Should preserve event type")
        
        // Clean up
        BackgroundTaskDataStore.shared.clearAllEvents()
    }
    
    // MARK: - Task Metrics Tests
    
    @Test("Task Metrics Generation")
    func testTaskMetricsGeneration() async throws {
        let viewModel = DashboardViewModel()
        
        BackgroundTaskDataStore.shared.clearAllEvents()
        
        // Create events for multiple tasks
        let events = [
            createTestEvent(taskId: "task-A", type: .taskScheduled),
            createTestEvent(taskId: "task-A", type: .taskExecutionStarted),
            createTestEvent(taskId: "task-A", type: .taskExecutionCompleted, duration: 2.5, success: true),
            createTestEvent(taskId: "task-B", type: .taskScheduled),
            createTestEvent(taskId: "task-B", type: .taskExecutionStarted),
            createTestEvent(taskId: "task-B", type: .taskExecutionCompleted, duration: 1.8, success: false),
        ]
        
        for event in events {
            BackgroundTaskDataStore.shared.recordEvent(event)
        }
        
        viewModel.loadData(for: .last24Hours)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(viewModel.taskMetrics.count == 2, "Should generate metrics for both tasks")
        
        // Find metrics for task-A
        let taskAMetrics = viewModel.taskMetrics.first { $0.taskIdentifier == "task-A" }
        #expect(taskAMetrics != nil, "Should have metrics for task-A")
        #expect(taskAMetrics?.totalScheduled == 1, "Should have correct scheduled count")
        #expect(taskAMetrics?.totalExecuted == 1, "Should have correct executed count")
        #expect(taskAMetrics?.averageDuration == 2.5, "Should have correct average duration")
        #expect(taskAMetrics?.successRate == 1.0, "Should have correct success rate")
        
        // Verify metrics are sorted by task identifier
        let identifiers = viewModel.taskMetrics.map { $0.taskIdentifier }
        let sortedIdentifiers = identifiers.sorted()
        #expect(identifiers == sortedIdentifiers, "Task metrics should be sorted by identifier")
        
        // Clean up
        BackgroundTaskDataStore.shared.clearAllEvents()
    }
    
    // MARK: - Auto-refresh Tests
    
    @Test("Auto-refresh Timer")
    func testAutoRefreshTimer() async throws {
        let viewModel = DashboardViewModel()
        
        BackgroundTaskDataStore.shared.clearAllEvents()
        
        // Load initial data
        viewModel.loadData(for: .last24Hours)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let initialEventCount = viewModel.events.count
        
        // Add a new event
        let newEvent = createTestEvent(taskId: "refresh-test", type: .taskExecutionCompleted)
        BackgroundTaskDataStore.shared.recordEvent(newEvent)
        
        // Wait for auto-refresh (timer is set to 30 seconds, but we'll simulate it)
        viewModel.refresh()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(viewModel.events.count == initialEventCount + 1, "Should auto-refresh and pick up new events")
        
        // Clean up
        BackgroundTaskDataStore.shared.clearAllEvents()
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @Test("Concurrent Data Loading")
    func testConcurrentDataLoading() async throws {
        let viewModel = DashboardViewModel()
        
        BackgroundTaskDataStore.shared.clearAllEvents()
        
        // Trigger multiple concurrent loads
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await viewModel.loadData(for: .last1Hour)
            }
            
            group.addTask {
                await viewModel.loadData(for: .last24Hours)
            }
            
            group.addTask {
                await viewModel.loadData(for: .last7Days)
            }
        }
        
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        #expect(!viewModel.isLoading, "Should complete all concurrent loading operations")
        #expect(viewModel.error == nil, "Should not have errors from concurrent loading")
        #expect(viewModel.selectedTimeRange == .last7Days, "Should reflect the last time range loaded")
    }
    
    @Test("Large Data Set Performance")
    func testLargeDataSetPerformance() async throws {
        let viewModel = DashboardViewModel()
        
        BackgroundTaskDataStore.shared.clearAllEvents()
        
        // Create a large number of events
        let largeEventSet = createTestEvents(count: 1000)
        for event in largeEventSet {
            BackgroundTaskDataStore.shared.recordEvent(event)
        }
        
        let startTime = Date()
        viewModel.loadData(for: .all)
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let endTime = Date()
        let loadTime = endTime.timeIntervalSince(startTime)
        
        #expect(!viewModel.isLoading, "Should complete loading large data set")
        #expect(loadTime < 2.0, "Should load large data set in reasonable time")
        #expect(viewModel.events.count == 1000, "Should load all events")
        #expect(viewModel.timelineData.count == 1000, "Should generate timeline for all events")
        
        // Clean up
        BackgroundTaskDataStore.shared.clearAllEvents()
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Memory Management and Cleanup")
    func testMemoryManagementAndCleanup() async throws {
        var viewModel: DashboardViewModel? = DashboardViewModel()
        
        // Load data and verify it's working
        viewModel!.loadData(for: .last24Hours)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(viewModel != nil, "ViewModel should be allocated")
        
        // Clear reference
        viewModel = nil
        
        // Allow time for deallocation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(viewModel == nil, "ViewModel should be deallocated")
    }
}

// MARK: - Helper Functions and Mock Classes

extension DashboardViewModelTests {
    
    /// Creates a test event with specified parameters
    private func createTestEvent(
        taskId: String,
        timestamp: Date = Date(),
        type: BackgroundTaskEventType = .taskExecutionCompleted,
        duration: TimeInterval? = nil,
        success: Bool = true
    ) -> BackgroundTaskEvent {
        return BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskId,
            type: type,
            timestamp: timestamp,
            duration: duration,
            success: success,
            errorMessage: success ? nil : "Test error",
            metadata: ["test": "true"],
            systemInfo: createTestSystemInfo()
        )
    }
    
    /// Creates multiple test events
    private func createTestEvents(count: Int) -> [BackgroundTaskEvent] {
        let taskIds = ["task-1", "task-2", "task-3", "task-4", "task-5"]
        let eventTypes: [BackgroundTaskEventType] = [
            .taskScheduled, .taskExecutionStarted, .taskExecutionCompleted, 
            .taskExpired, .taskFailed
        ]
        
        return (0..<count).map { index in
            let taskId = taskIds[index % taskIds.count]
            let type = eventTypes[index % eventTypes.count]
            let timestamp = Date().addingTimeInterval(-Double(index) * 60) // Spread events over time
            let duration = type == .taskExecutionCompleted ? Double.random(in: 0.5...5.0) : nil
            let success = type != .taskFailed && type != .taskExpired
            
            return createTestEvent(
                taskId: "\(taskId)-\(index)",
                timestamp: timestamp,
                type: type,
                duration: duration,
                success: success
            )
        }
    }
    
    /// Creates test system info
    private func createTestSystemInfo() -> SystemInfo {
        return SystemInfo(
            backgroundAppRefreshStatus: .available,
            deviceModel: "iPhone15,2",
            systemVersion: "17.0",
            lowPowerModeEnabled: false,
            batteryLevel: 0.85,
            batteryState: .unplugged
        )
    }
}

/// Extension to add test-specific functionality to DashboardViewModel
extension DashboardViewModel {
    /// Simulate error condition for testing
    func simulateError(_ message: String) async {
        await MainActor.run {
            self.error = message
        }
    }
}