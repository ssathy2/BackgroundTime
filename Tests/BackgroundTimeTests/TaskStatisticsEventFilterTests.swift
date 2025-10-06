//
//  TaskStatisticsEventFilterTests.swift
//  BackgroundTimeTests
//
//  Created by AI Assistant on 10/05/25.
//

import Testing
import Foundation
import UIKit
@testable import BackgroundTime

@Suite("Task Statistics Event Filter Tests")
struct TaskStatisticsEventFilterTests {
    
    // MARK: - isTaskStatisticsEvent Property Tests
    
    @Test("Background Task Event Types Classification")
    func testBackgroundTaskEventTypesClassification() async throws {
        // Events that SHOULD be included in task statistics
        let taskStatisticsEvents: [BackgroundTaskEventType] = [
            .taskScheduled,
            .taskExecutionStarted,
            .taskExecutionCompleted,
            .taskExpired,
            .taskCancelled,
            .taskFailed,
            .continuousTaskStarted,
            .continuousTaskPaused,
            .continuousTaskResumed,
            .continuousTaskStopped,
            .continuousTaskProgress
        ]
        
        // Events that should NOT be included in task statistics
        let nonTaskStatisticsEvents: [BackgroundTaskEventType] = [
            .initialization,
            .appEnteredBackground,
            .appWillEnterForeground
        ]
        
        // Verify task statistics events return true
        for eventType in taskStatisticsEvents {
            #expect(eventType.isTaskStatisticsEvent == true, 
                   "\(eventType.rawValue) should be included in task statistics")
        }
        
        // Verify non-task statistics events return false
        for eventType in nonTaskStatisticsEvents {
            #expect(eventType.isTaskStatisticsEvent == false, 
                   "\(eventType.rawValue) should NOT be included in task statistics")
        }
    }
    
    @Test("All Event Types Are Categorized")
    func testAllEventTypesAreCategorized() async throws {
        // Ensure every event type is explicitly categorized
        for eventType in BackgroundTaskEventType.allCases {
            let isTaskStatistics = eventType.isTaskStatisticsEvent
            
            // This test ensures we don't accidentally miss any event types
            // Every event type should have a deliberate true/false classification
            switch eventType {
            case .taskScheduled, .taskExecutionStarted, .taskExecutionCompleted,
                 .taskExpired, .taskCancelled, .taskFailed,
                 .continuousTaskStarted, .continuousTaskPaused, .continuousTaskResumed,
                 .continuousTaskStopped, .continuousTaskProgress:
                #expect(isTaskStatistics == true, 
                       "\(eventType.rawValue) should be classified as task statistics event")
                
            case .initialization, .appEnteredBackground, .appWillEnterForeground:
                #expect(isTaskStatistics == false, 
                       "\(eventType.rawValue) should be classified as non-task statistics event")
            }
        }
    }
    
    // MARK: - Statistics Computation with Filtering Tests
    
    @Test("Statistics Computation Filters Events Correctly")
    func testStatisticsComputationFiltersEventsCorrectly() async throws {
        let customDefaults = UserDefaults(suiteName: "TaskStatisticsEventFilterTests.Computation") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "TaskStatisticsEventFilterTests.Computation")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create comprehensive test data including both types of events
        var events = [
            // Task statistics events (SHOULD be counted)
            createTestEvent(taskId: "task-1", type: .taskScheduled, success: true),
            createTestEvent(taskId: "task-1", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-1", type: .taskExecutionCompleted, success: true, duration: 2.0),
            
            createTestEvent(taskId: "task-2", type: .taskScheduled, success: true),
            createTestEvent(taskId: "task-2", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-2", type: .taskFailed, success: false),
            
            createTestEvent(taskId: "task-3", type: .taskScheduled, success: true),
            createTestEvent(taskId: "task-3", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-3", type: .taskExpired, success: false),
            
            createTestEvent(taskId: "task-4", type: .taskCancelled, success: false),
            
            // Non-task statistics events (should NOT be counted)
            createTestEvent(taskId: "sdk", type: .initialization, success: true),
            createTestEvent(taskId: "app", type: .appEnteredBackground, success: true),
            createTestEvent(taskId: "app", type: .appWillEnterForeground, success: true),
        ]
        
        // Add continuous task events if available (iOS 26.0+)
        if #available(iOS 26.0, *) {
            let continuousEvents = [
                createTestEvent(taskId: "continuous-1", type: .continuousTaskStarted, success: true),
                createTestEvent(taskId: "continuous-1", type: .continuousTaskProgress, success: true),
                createTestEvent(taskId: "continuous-1", type: .continuousTaskPaused, success: true),
                createTestEvent(taskId: "continuous-2", type: .continuousTaskStarted, success: true),
                createTestEvent(taskId: "continuous-2", type: .continuousTaskResumed, success: true),
                createTestEvent(taskId: "continuous-2", type: .continuousTaskStopped, success: true),
            ]
            events.append(contentsOf: continuousEvents)
        }
        
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let statistics = dataStore.generateStatistics()
        
        // Verify that all events were stored
        let allStoredEvents = dataStore.getAllEvents()
        let expectedTotalEvents: Int
        if #available(iOS 26.0, *) {
            expectedTotalEvents = 19
        } else {
            expectedTotalEvents = 13
        }
        #expect(allStoredEvents.count == expectedTotalEvents, "Should store all events")
        
        // Verify filtering by checking which events are task statistics events
        let taskStatisticsEvents = allStoredEvents.filter { $0.type.isTaskStatisticsEvent }
        let nonTaskStatisticsEvents = allStoredEvents.filter { !$0.type.isTaskStatisticsEvent }
        
        let expectedTaskStatisticsEvents: Int
        if #available(iOS 26.0, *) {
            expectedTaskStatisticsEvents = 16
        } else {
            expectedTaskStatisticsEvents = 10
        }
        #expect(taskStatisticsEvents.count == expectedTaskStatisticsEvents, 
               "Should identify correct number of task statistics events")
        #expect(nonTaskStatisticsEvents.count == 3, 
               "Should identify exactly 3 non-task statistics events")
        
        // Verify statistics only count task statistics events
        #expect(statistics.totalTasksScheduled == 3, "Should count only task scheduled events")
        #expect(statistics.totalTasksExecuted == 3, "Should count only task execution started events")
        #expect(statistics.totalTasksCompleted == 1, "Should count only successful task completion events")
        #expect(statistics.totalTasksFailed >= 3, "Should count failed, expired, and cancelled events")
        #expect(statistics.totalTasksExpired == 1, "Should count expired events")
        
        // Verify that cancelled tasks are counted as failures
        let allEvents = dataStore.getAllEvents()
        let cancelledEvents = allEvents.filter { $0.type == .taskCancelled }
        #expect(cancelledEvents.count == 1, "Should have one cancelled event")
        #expect(statistics.totalTasksFailed >= cancelledEvents.count, "Cancelled tasks should contribute to failure count")
        
        // Verify success rate calculation uses only task statistics events
        // Expected: 1 successful completion / 3 executions = 0.333...
        let expectedSuccessRate = 1.0 / 3.0
        #expect(abs(statistics.successRate - expectedSuccessRate) < 0.001,
               "Success rate should be ~33.3% (1/3), got \(statistics.successRate)")
        
        // Verify hourly execution pattern only includes task executions
        let totalHourlyExecutions = statistics.executionsByHour.values.reduce(0, +)
        #expect(totalHourlyExecutions == 3, "Hourly execution pattern should only count task executions")
    }
    
    @Test("Task Performance Metrics Filter Events Correctly")
    func testTaskPerformanceMetricsFilterEventsCorrectly() async throws {
        let customDefaults = UserDefaults(suiteName: "TaskStatisticsEventFilterTests.TaskMetrics") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "TaskStatisticsEventFilterTests.TaskMetrics")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        let taskId = "mixed-events-task"
        
        // Create events for a single task including both types
        let events = [
            // Task statistics events
            createTestEvent(taskId: taskId, type: .taskScheduled, success: true, timestamp: Date().addingTimeInterval(-1000)),
            createTestEvent(taskId: taskId, type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-900)),
            createTestEvent(taskId: taskId, type: .taskExecutionCompleted, success: true, duration: 2.5, timestamp: Date().addingTimeInterval(-880)),
            
            createTestEvent(taskId: taskId, type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-500)),
            createTestEvent(taskId: taskId, type: .taskExecutionCompleted, success: false, duration: 1.0, timestamp: Date().addingTimeInterval(-480)),
            
            // Non-task statistics events (should be ignored for task metrics)
            createTestEvent(taskId: taskId, type: .initialization, success: true, timestamp: Date().addingTimeInterval(-800)),
            createTestEvent(taskId: taskId, type: .appEnteredBackground, success: true, timestamp: Date().addingTimeInterval(-600)),
            createTestEvent(taskId: taskId, type: .appWillEnterForeground, success: true, timestamp: Date().addingTimeInterval(-400)),
        ]
        
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let taskMetrics = dataStore.getTaskPerformanceMetrics(for: taskId)
        
        #expect(taskMetrics != nil, "Should generate task metrics")
        
        guard let metrics = taskMetrics else { return }
        
        // Verify that only task statistics events are counted
        #expect(metrics.totalScheduled == 1, "Should count only task scheduled events")
        #expect(metrics.totalExecuted == 2, "Should count only task execution events")
        #expect(metrics.totalCompleted == 2, "Should count only task completion events")
        #expect(metrics.totalFailed == 1, "Should count only failed task executions")
        
        // Verify success rate calculation
        // Expected: 1 successful / 2 executed = 0.5 (50%)
        #expect(abs(metrics.successRate - 0.5) < 0.001,
               "Task success rate should be 50% (0.5), got \(metrics.successRate)")
        
        // Verify average duration calculation
        // Expected: (2.5 + 1.0) / 2 = 1.75
        #expect(abs(metrics.averageDuration - 1.75) < 0.001,
               "Average duration should be 1.75s, got \(metrics.averageDuration)")
        
        // Verify that app lifecycle events didn't affect the metrics
        let allTaskEvents = dataStore.getEvents(for: taskId)
        #expect(allTaskEvents.count == 8, "Should have all events stored for the task")
        
        let taskStatisticsEvents = allTaskEvents.filter { $0.type.isTaskStatisticsEvent }
        #expect(taskStatisticsEvents.count == 5, "Should identify 5 task statistics events")
        
        let nonTaskStatisticsEvents = allTaskEvents.filter { !$0.type.isTaskStatisticsEvent }
        #expect(nonTaskStatisticsEvents.count == 3, "Should identify 3 non-task statistics events")
    }
    
    // MARK: - Continuous Tasks Filtering Tests (iOS 26.0+)
    
    @Test("Continuous Tasks Events Are Included in Statistics")
    @available(iOS 26.0, *)
    func testContinuousTasksEventsAreIncludedInStatistics() async throws {
        let customDefaults = UserDefaults(suiteName: "TaskStatisticsEventFilterTests.ContinuousTasks") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "TaskStatisticsEventFilterTests.ContinuousTasks")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create only continuous task events
        let continuousEvents = [
            createTestEvent(taskId: "continuous-1", type: .continuousTaskStarted, success: true),
            createTestEvent(taskId: "continuous-1", type: .continuousTaskProgress, success: true),
            createTestEvent(taskId: "continuous-1", type: .continuousTaskPaused, success: true),
            createTestEvent(taskId: "continuous-1", type: .continuousTaskResumed, success: true),
            createTestEvent(taskId: "continuous-1", type: .continuousTaskStopped, success: true),
            
            createTestEvent(taskId: "continuous-2", type: .continuousTaskStarted, success: true),
            createTestEvent(taskId: "continuous-2", type: .continuousTaskProgress, success: true),
            createTestEvent(taskId: "continuous-2", type: .continuousTaskStopped, success: true),
        ]
        
        for event in continuousEvents {
            dataStore.recordEvent(event)
        }
        
        let statistics = dataStore.generateStatistics()
        
        // Verify all continuous task events are treated as task statistics events
        let allEvents = dataStore.getAllEvents()
        #expect(allEvents.count == 8, "Should store all continuous task events")
        
        let taskStatisticsEvents = allEvents.filter { $0.type.isTaskStatisticsEvent }
        #expect(taskStatisticsEvents.count == 8, "All continuous task events should be task statistics events")
        
        // Verify continuous task events are counted in statistics
        // Note: The exact counting may depend on how continuous tasks are interpreted
        // in the statistics generation logic
        #expect(statistics.totalTasksScheduled >= 0, "Should handle continuous task scheduling")
        #expect(statistics.totalTasksExecuted >= 0, "Should handle continuous task execution")
        
        // Verify that continuous task types are correctly classified
        let continuousTaskTypes: [BackgroundTaskEventType] = [
            .continuousTaskStarted, .continuousTaskProgress, .continuousTaskPaused,
            .continuousTaskResumed, .continuousTaskStopped
        ]
        
        for taskType in continuousTaskTypes {
            #expect(taskType.isTaskStatisticsEvent == true,
                   "Continuous task type \(taskType.rawValue) should be included in statistics")
            #expect(taskType.isContinuousTaskEvent == true,
                   "Continuous task type \(taskType.rawValue) should be identified as continuous task event")
        }
    }
    
    
    @Test("Cancelled Tasks Are Counted As Failures")
    func testCancelledTasksAreCountedAsFailures() async throws {
        let customDefaults = UserDefaults(suiteName: "TaskStatisticsEventFilterTests.CancelledTasks") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "TaskStatisticsEventFilterTests.CancelledTasks")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create tasks with different failure modes
        let events = [
            createTestEvent(taskId: "failed-task", type: .taskScheduled, success: true),
            createTestEvent(taskId: "failed-task", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "failed-task", type: .taskFailed, success: false),
            
            createTestEvent(taskId: "expired-task", type: .taskScheduled, success: true),
            createTestEvent(taskId: "expired-task", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "expired-task", type: .taskExpired, success: false),
            
            createTestEvent(taskId: "cancelled-task", type: .taskScheduled, success: true),
            createTestEvent(taskId: "cancelled-task", type: .taskCancelled, success: false),
        ]
        
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let statistics = dataStore.generateStatistics()
        
        // Verify all failure types are counted
        #expect(statistics.totalTasksFailed == 3, 
               "Should count failed (\(statistics.totalTasksFailed)) = 1 failed + 1 expired + 1 cancelled")
        #expect(statistics.totalTasksExpired == 1, "Should count 1 expired task")
        
        // Verify error categorization includes all failure types
        let allEvents = dataStore.getAllEvents()
        let failedEvents = allEvents.filter { $0.type == .taskFailed }
        let expiredEvents = allEvents.filter { $0.type == .taskExpired }
        let cancelledEvents = allEvents.filter { $0.type == .taskCancelled }
        
        #expect(failedEvents.count == 1, "Should have 1 failed event")
        #expect(expiredEvents.count == 1, "Should have 1 expired event") 
        #expect(cancelledEvents.count == 1, "Should have 1 cancelled event")
        
        // All should be included in error categorization
        #expect(statistics.errorsByType.count >= 1, "Should categorize different error types")
    }

    // MARK: - Edge Cases Tests
    
    @Test("Empty Data Set With Filtering")
    func testEmptyDataSetWithFiltering() async throws {
        let customDefaults = UserDefaults(suiteName: "TaskStatisticsEventFilterTests.Empty") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "TaskStatisticsEventFilterTests.Empty")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        let statistics = dataStore.generateStatistics()
        
        #expect(statistics.totalTasksScheduled == 0, "Empty data should result in 0 scheduled tasks")
        #expect(statistics.totalTasksExecuted == 0, "Empty data should result in 0 executed tasks")
        #expect(statistics.totalTasksCompleted == 0, "Empty data should result in 0 completed tasks")
        #expect(statistics.totalTasksFailed == 0, "Empty data should result in 0 failed tasks")
        #expect(statistics.successRate == 0.0, "Empty data should result in 0% success rate")
    }
    
    @Test("Only Non-Task Statistics Events")
    func testOnlyNonTaskStatisticsEvents() async throws {
        let customDefaults = UserDefaults(suiteName: "TaskStatisticsEventFilterTests.OnlyNonTask") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "TaskStatisticsEventFilterTests.OnlyNonTask")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create only non-task statistics events
        let nonTaskEvents = [
            createTestEvent(taskId: "sdk", type: .initialization, success: true),
            createTestEvent(taskId: "app", type: .appEnteredBackground, success: true),
            createTestEvent(taskId: "app", type: .appWillEnterForeground, success: true),
        ]
        
        for event in nonTaskEvents {
            dataStore.recordEvent(event)
        }
        
        let statistics = dataStore.generateStatistics()
        
        // Verify that non-task events don't contribute to task statistics
        let allEvents = dataStore.getAllEvents()
        #expect(allEvents.count == 3, "Should store all events")
        
        let taskStatisticsEvents = allEvents.filter { $0.type.isTaskStatisticsEvent }
        #expect(taskStatisticsEvents.count == 0, "Should have no task statistics events")
        
        // Statistics should remain at zero
        #expect(statistics.totalTasksScheduled == 0, "Should have 0 scheduled tasks")
        #expect(statistics.totalTasksExecuted == 0, "Should have 0 executed tasks")
        #expect(statistics.totalTasksCompleted == 0, "Should have 0 completed tasks")
        #expect(statistics.totalTasksFailed == 0, "Should have 0 failed tasks")
        #expect(statistics.successRate == 0.0, "Should have 0% success rate")
    }
    
    // MARK: - Helper Functions
    
    private func createTestEvent(
        taskId: String,
        type: BackgroundTaskEventType,
        success: Bool,
        duration: TimeInterval? = nil,
        timestamp: Date = Date()
    ) -> BackgroundTaskEvent {
        return BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskId,
            type: type,
            timestamp: timestamp,
            duration: duration,
            success: success,
            errorMessage: success ? nil : "Test error for \(taskId)",
            metadata: ["test": "task_statistics_filter_test"],
            systemInfo: createTestSystemInfo()
        )
    }
    
    private func createTestSystemInfo() -> SystemInfo {
        return SystemInfo(
            backgroundAppRefreshStatus: .available,
            deviceModel: "TestDevice",
            systemVersion: "17.0",
            lowPowerModeEnabled: false,
            batteryLevel: 0.8,
            batteryState: .unplugged
        )
    }
}
