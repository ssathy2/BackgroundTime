//
//  SuccessRateTests.swift
//  BackgroundTimeTests
//
//  Created by AI Assistant on 10/04/25.
//

import Testing
import Foundation
import UIKit
@testable import BackgroundTime

// MARK: - Success Rate Calculation Tests

@Suite("Success Rate Calculation Tests")
@MainActor
struct SuccessRateTests {
    
    // MARK: - Basic Success Rate Tests
    
    @Test("Success Rate with All Successful Tasks")
    func testSuccessRateAllSuccessful() async throws {
        let customDefaults = UserDefaults(suiteName: "SuccessRateTests.AllSuccessful") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "SuccessRateTests.AllSuccessful")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create events for a successful task execution
        let startEvent = createTestEvent(taskId: "task-1", type: .taskExecutionStarted, success: true)
        let completionEvent = createTestEvent(taskId: "task-1", type: .taskExecutionCompleted, success: true, duration: 2.0)
        
        dataStore.recordEvent(startEvent)
        dataStore.recordEvent(completionEvent)
        
        let statistics = dataStore.generateStatistics()
        
        #expect(statistics.totalTasksExecuted == 1, "Should have 1 executed task")
        #expect(statistics.totalTasksCompleted == 1, "Should have 1 completed task")
        #expect(statistics.totalTasksFailed == 0, "Should have 0 failed tasks")
        #expect(statistics.successRate == 1.0, "Success rate should be 100% (1.0)")
    }
    
    @Test("Success Rate with All Failed Tasks")
    func testSuccessRateAllFailed() async throws {
        let customDefaults = UserDefaults(suiteName: "SuccessRateTests.AllFailed") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "SuccessRateTests.AllFailed")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create events for a failed task execution
        let startEvent = createTestEvent(taskId: "task-1", type: .taskExecutionStarted, success: true)
        let failedEvent = createTestEvent(taskId: "task-1", type: .taskExecutionCompleted, success: false, duration: 1.0)
        
        dataStore.recordEvent(startEvent)
        dataStore.recordEvent(failedEvent)
        
        let statistics = dataStore.generateStatistics()
        
        #expect(statistics.totalTasksExecuted == 1, "Should have 1 executed task")
        #expect(statistics.totalTasksCompleted == 1, "Should have 1 completed task")
        #expect(statistics.totalTasksFailed == 1, "Should have 1 failed task")
        #expect(statistics.successRate == 0.0, "Success rate should be 0% (0.0)")
    }
    
    @Test("Success Rate with Mixed Results")
    func testSuccessRateMixedResults() async throws {
        let customDefaults = UserDefaults(suiteName: "SuccessRateTests.Mixed") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "SuccessRateTests.Mixed")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create events for mixed task results: 3 successful, 2 failed
        let events = [
            // Task 1 - successful
            createTestEvent(taskId: "task-1", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-1", type: .taskExecutionCompleted, success: true, duration: 2.0),
            
            // Task 2 - failed
            createTestEvent(taskId: "task-2", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-2", type: .taskExecutionCompleted, success: false, duration: 1.0),
            
            // Task 3 - successful
            createTestEvent(taskId: "task-3", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-3", type: .taskExecutionCompleted, success: true, duration: 3.0),
            
            // Task 4 - failed
            createTestEvent(taskId: "task-4", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-4", type: .taskExecutionCompleted, success: false, duration: 0.5),
            
            // Task 5 - successful
            createTestEvent(taskId: "task-5", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-5", type: .taskExecutionCompleted, success: true, duration: 1.5)
        ]
        
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let statistics = dataStore.generateStatistics()
        
        #expect(statistics.totalTasksExecuted == 5, "Should have 5 executed tasks")
        #expect(statistics.totalTasksCompleted == 5, "Should have 5 completed tasks")
        #expect(statistics.totalTasksFailed == 2, "Should have 2 failed tasks")
        
        // Expected success rate: 3 successful / 5 executed = 0.6 (60%)
        #expect(abs(statistics.successRate - 0.6) < 0.001, "Success rate should be 60% (0.6), got \(statistics.successRate)")
    }
    
    @Test("Success Rate with Expired Tasks")
    func testSuccessRateWithExpiredTasks() async throws {
        let customDefaults = UserDefaults(suiteName: "SuccessRateTests.Expired") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "SuccessRateTests.Expired")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create events: 2 successful, 1 failed, 2 expired
        let events = [
            // Task 1 - successful
            createTestEvent(taskId: "task-1", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-1", type: .taskExecutionCompleted, success: true, duration: 2.0),
            
            // Task 2 - failed
            createTestEvent(taskId: "task-2", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-2", type: .taskExecutionCompleted, success: false, duration: 1.0),
            
            // Task 3 - expired
            createTestEvent(taskId: "task-3", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-3", type: .taskExpired, success: false),
            
            // Task 4 - successful
            createTestEvent(taskId: "task-4", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-4", type: .taskExecutionCompleted, success: true, duration: 1.5),
            
            // Task 5 - expired
            createTestEvent(taskId: "task-5", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-5", type: .taskExpired, success: false)
        ]
        
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let statistics = dataStore.generateStatistics()
        
        #expect(statistics.totalTasksExecuted == 5, "Should have 5 executed tasks")
        #expect(statistics.totalTasksCompleted == 3, "Should have 3 completed tasks (2 successful + 1 failed, not counting expired)")
        #expect(statistics.totalTasksFailed == 3, "Should have 3 failed tasks (1 failed + 2 expired)")
        #expect(statistics.totalTasksExpired == 2, "Should have 2 expired tasks")
        
        // Expected success rate: 2 successful / 5 executed = 0.4 (40%)
        #expect(abs(statistics.successRate - 0.4) < 0.001, "Success rate should be 40% (0.4), got \(statistics.successRate)")
    }
    
    // MARK: - Edge Cases
    
    @Test("Success Rate with No Executed Tasks")
    func testSuccessRateNoExecutedTasks() async throws {
        let customDefaults = UserDefaults(suiteName: "SuccessRateTests.NoExecuted") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "SuccessRateTests.NoExecuted")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Only add scheduled events, no executions
        let scheduledEvent = createTestEvent(taskId: "task-1", type: .taskScheduled, success: true)
        dataStore.recordEvent(scheduledEvent)
        
        let statistics = dataStore.generateStatistics()
        
        #expect(statistics.totalTasksExecuted == 0, "Should have 0 executed tasks")
        #expect(statistics.totalTasksCompleted == 0, "Should have 0 completed tasks")
        #expect(statistics.successRate == 0.0, "Success rate should be 0 when no tasks executed")
    }
    
    @Test("Success Rate with Only Failed Events")
    func testSuccessRateOnlyFailedEvents() async throws {
        let customDefaults = UserDefaults(suiteName: "SuccessRateTests.OnlyFailed") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "SuccessRateTests.OnlyFailed")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create explicit failed events without execution start events (edge case)
        let failedEvent1 = createTestEvent(taskId: "task-1", type: .taskFailed, success: false)
        let failedEvent2 = createTestEvent(taskId: "task-2", type: .taskFailed, success: false)
        
        dataStore.recordEvent(failedEvent1)
        dataStore.recordEvent(failedEvent2)
        
        let statistics = dataStore.generateStatistics()
        
        #expect(statistics.totalTasksExecuted == 0, "Should have 0 executed tasks (no start events)")
        #expect(statistics.totalTasksFailed == 2, "Should have 2 failed tasks")
        #expect(statistics.successRate == 0.0, "Success rate should be 0 when no executions recorded")
    }
    
    @Test("Success Rate with Completion Events Only")
    func testSuccessRateCompletionEventsOnly() async throws {
        let customDefaults = UserDefaults(suiteName: "SuccessRateTests.CompletionOnly") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "SuccessRateTests.CompletionOnly")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create completion events without start events (fallback case)
        let completion1 = createTestEvent(taskId: "task-1", type: .taskExecutionCompleted, success: true, duration: 2.0)
        let completion2 = createTestEvent(taskId: "task-2", type: .taskExecutionCompleted, success: false, duration: 1.0)
        let completion3 = createTestEvent(taskId: "task-3", type: .taskExecutionCompleted, success: true, duration: 1.5)
        
        dataStore.recordEvent(completion1)
        dataStore.recordEvent(completion2)
        dataStore.recordEvent(completion3)
        
        let statistics = dataStore.generateStatistics()
        
        // When no execution start events exist, fallback to using completion events as executed count
        #expect(statistics.totalTasksExecuted == 3, "Should infer 3 executed tasks from completion events")
        #expect(statistics.totalTasksCompleted == 3, "Should have 3 completed tasks")
        #expect(statistics.totalTasksFailed == 1, "Should have 1 failed task")
        
        // Expected success rate: 2 successful / 3 executed = 0.667 (66.7%)
        #expect(abs(statistics.successRate - (2.0/3.0)) < 0.001, "Success rate should be ~66.7% (2/3), got \(statistics.successRate)")
    }
    
    // MARK: - Individual Task Performance Metrics Tests
    
    @Test("Individual Task Success Rate Calculation")
    func testIndividualTaskSuccessRate() async throws {
        let customDefaults = UserDefaults(suiteName: "SuccessRateTests.IndividualTask") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "SuccessRateTests.IndividualTask")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create multiple executions for one task: 3 successful, 2 failed
        let events = [
            // Execution 1 - successful
            createTestEvent(taskId: "recurring-task", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-400)),
            createTestEvent(taskId: "recurring-task", type: .taskExecutionCompleted, success: true, duration: 2.0, timestamp: Date().addingTimeInterval(-398)),
            
            // Execution 2 - failed
            createTestEvent(taskId: "recurring-task", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-300)),
            createTestEvent(taskId: "recurring-task", type: .taskExecutionCompleted, success: false, duration: 1.0, timestamp: Date().addingTimeInterval(-299)),
            
            // Execution 3 - successful
            createTestEvent(taskId: "recurring-task", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-200)),
            createTestEvent(taskId: "recurring-task", type: .taskExecutionCompleted, success: true, duration: 3.0, timestamp: Date().addingTimeInterval(-197)),
            
            // Execution 4 - failed
            createTestEvent(taskId: "recurring-task", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-100)),
            createTestEvent(taskId: "recurring-task", type: .taskExecutionCompleted, success: false, duration: 0.5, timestamp: Date().addingTimeInterval(-99)),
            
            // Execution 5 - successful
            createTestEvent(taskId: "recurring-task", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-50)),
            createTestEvent(taskId: "recurring-task", type: .taskExecutionCompleted, success: true, duration: 1.5, timestamp: Date().addingTimeInterval(-48))
        ]
        
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let taskMetrics = dataStore.getTaskPerformanceMetrics(for: "recurring-task")
        
        #expect(taskMetrics != nil, "Should have task metrics")
        
        guard let metrics = taskMetrics else { return }
        
        #expect(metrics.totalExecuted == 5, "Should have 5 executed instances")
        #expect(metrics.totalCompleted == 5, "Should have 5 completed instances")
        #expect(metrics.totalFailed == 2, "Should have 2 failed instances")
        
        // Expected success rate: 3 successful / 5 executed = 0.6 (60%)
        #expect(abs(metrics.successRate - 0.6) < 0.001, "Task success rate should be 60% (0.6), got \(metrics.successRate)")
    }
    
    @Test("Task Success Rate with Expired Tasks")
    func testTaskSuccessRateWithExpired() async throws {
        let customDefaults = UserDefaults(suiteName: "SuccessRateTests.TaskExpired") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "SuccessRateTests.TaskExpired")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create task executions: 1 successful, 1 failed, 1 expired
        let events = [
            // Execution 1 - successful
            createTestEvent(taskId: "task-with-mixed-results", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-300)),
            createTestEvent(taskId: "task-with-mixed-results", type: .taskExecutionCompleted, success: true, duration: 2.0, timestamp: Date().addingTimeInterval(-298)),
            
            // Execution 2 - failed
            createTestEvent(taskId: "task-with-mixed-results", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-200)),
            createTestEvent(taskId: "task-with-mixed-results", type: .taskExecutionCompleted, success: false, duration: 1.0, timestamp: Date().addingTimeInterval(-199)),
            
            // Execution 3 - expired
            createTestEvent(taskId: "task-with-mixed-results", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-100)),
            createTestEvent(taskId: "task-with-mixed-results", type: .taskExpired, success: false, timestamp: Date().addingTimeInterval(-99))
        ]
        
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let taskMetrics = dataStore.getTaskPerformanceMetrics(for: "task-with-mixed-results")
        
        #expect(taskMetrics != nil, "Should have task metrics")
        
        guard let metrics = taskMetrics else { return }
        
        #expect(metrics.totalExecuted == 3, "Should have 3 executed instances")
        #expect(metrics.totalCompleted == 2, "Should have 2 completed instances (1 successful + 1 failed, not counting expired)")
        #expect(metrics.totalFailed == 2, "Should have 2 failed instances (1 failed + 1 expired)")
        
        // Expected success rate: 1 successful / 3 executed = 0.333... (33.3%)
        #expect(abs(metrics.successRate - (1.0/3.0)) < 0.001, "Task success rate should be ~33.3% (1/3), got \(metrics.successRate)")
    }
    
    // MARK: - Dashboard Integration Tests
    
    @Test("Dashboard Success Rate Display")
    func testDashboardSuccessRateDisplay() async throws {
        let customDefaults = UserDefaults(suiteName: "SuccessRateTests.Dashboard") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "SuccessRateTests.Dashboard")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create realistic task execution data
        let events = [
            // Task 1 - successful (short duration)
            createTestEvent(taskId: "background-sync", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-1000)),
            createTestEvent(taskId: "background-sync", type: .taskExecutionCompleted, success: true, duration: 1.2, timestamp: Date().addingTimeInterval(-998.8)),
            
            // Task 2 - successful (medium duration)
            createTestEvent(taskId: "data-upload", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-800)),
            createTestEvent(taskId: "data-upload", type: .taskExecutionCompleted, success: true, duration: 3.5, timestamp: Date().addingTimeInterval(-796.5)),
            
            // Task 3 - failed (timeout)
            createTestEvent(taskId: "heavy-processing", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-600)),
            createTestEvent(taskId: "heavy-processing", type: .taskExecutionCompleted, success: false, duration: 30.0, timestamp: Date().addingTimeInterval(-570)),
            
            // Task 4 - expired
            createTestEvent(taskId: "image-processing", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-400)),
            createTestEvent(taskId: "image-processing", type: .taskExpired, success: false, timestamp: Date().addingTimeInterval(-370)),
            
            // Task 5 - successful (long duration)
            createTestEvent(taskId: "backup-operation", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-200)),
            createTestEvent(taskId: "backup-operation", type: .taskExecutionCompleted, success: true, duration: 15.8, timestamp: Date().addingTimeInterval(-184.2)),
        ]
        
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let viewModel = DashboardViewModel(dataStore: dataStore)
        await viewModel.loadData(for: .last24Hours, forceReload: true)
        
        #expect(viewModel.statistics != nil, "Dashboard should have statistics")
        
        guard let stats = viewModel.statistics else { return }
        
        #expect(stats.totalTasksExecuted == 5, "Dashboard should show 5 executed tasks")
        #expect(stats.totalTasksCompleted == 4, "Dashboard should show 4 completed tasks (3 successful + 1 failed, not counting expired)")
        #expect(stats.totalTasksFailed == 2, "Dashboard should show 2 failed tasks (1 failed + 1 expired)")
        
        // Expected success rate: 3 successful / 5 executed = 0.6 (60%)
        #expect(abs(stats.successRate - 0.6) < 0.001, "Dashboard success rate should be 60% (0.6), got \(stats.successRate)")
        
        // Verify task metrics in dashboard
        #expect(viewModel.taskMetrics.count >= 1, "Dashboard should have task metrics")
        
        // Check individual task metrics
        for taskMetric in viewModel.taskMetrics {
            #expect(taskMetric.successRate >= 0.0 && taskMetric.successRate <= 1.0, 
                   "Each task success rate should be between 0 and 1, got \(taskMetric.successRate) for \(taskMetric.taskIdentifier)")
        }
        
        // Test specific task success rates
        if let syncTaskMetric = viewModel.taskMetrics.first(where: { $0.taskIdentifier == "background-sync" }) {
            #expect(syncTaskMetric.successRate == 1.0, "Background sync task should have 100% success rate")
        }
        
        if let heavyTaskMetric = viewModel.taskMetrics.first(where: { $0.taskIdentifier == "heavy-processing" }) {
            #expect(heavyTaskMetric.successRate == 0.0, "Heavy processing task should have 0% success rate")
        }
    }
    
    @Test("Success Rate Excludes Non-Task Statistics Events")
    func testSuccessRateExcludesNonTaskStatisticsEvents() async throws {
        let customDefaults = UserDefaults(suiteName: "SuccessRateTests.FilteringEvents") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "SuccessRateTests.FilteringEvents")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create a mix of task statistics events and non-statistics events
        let events = [
            // Task statistics events (should be counted)
            createTestEvent(taskId: "task-1", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-1", type: .taskExecutionCompleted, success: true, duration: 2.0),
            createTestEvent(taskId: "task-2", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-2", type: .taskExecutionCompleted, success: false, duration: 1.0),
            
            // Non-task statistics events (should be excluded from statistics)
            createTestEvent(taskId: "sdk", type: .initialization, success: true),
            createTestEvent(taskId: "app", type: .appEnteredBackground, success: true),
            createTestEvent(taskId: "app", type: .appWillEnterForeground, success: true),
        ]
        
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let statistics = dataStore.generateStatistics()
        
        // Verify that only task statistics events are counted
        let allEvents = dataStore.getAllEvents()
        #expect(allEvents.count == 7, "Should store all events")
        
        let taskStatisticsEvents = allEvents.filter { $0.type.isTaskStatisticsEvent }
        #expect(taskStatisticsEvents.count == 4, "Should identify 4 task statistics events")
        
        let nonTaskStatisticsEvents = allEvents.filter { !$0.type.isTaskStatisticsEvent }
        #expect(nonTaskStatisticsEvents.count == 3, "Should identify 3 non-task statistics events")
        
        // Statistics should only reflect task statistics events
        #expect(statistics.totalTasksExecuted == 2, "Should count only task executions, not app lifecycle events")
        #expect(statistics.totalTasksCompleted == 2, "Should count only task completions")
        #expect(statistics.totalTasksFailed == 1, "Should count only task failures")
        
        // Expected success rate: 1 successful / 2 executed = 0.5 (50%)
        #expect(abs(statistics.successRate - 0.5) < 0.001, "Success rate should be 50% (0.5), got \(statistics.successRate)")
        
        // Verify that non-task events are not affecting the success rate calculation
        let expectedExecutionsByHour = Dictionary(grouping: taskStatisticsEvents.filter { $0.type == .taskExecutionStarted }) { event in
            Calendar.current.component(.hour, from: event.timestamp)
        }.mapValues { $0.count }
        
        #expect(statistics.executionsByHour.values.reduce(0, +) == 2, "Executions by hour should only count task executions")
    }
    
    // MARK: - Aggregation Report Tests
    
    @Test("Aggregation Report Success Rate Calculation")
    func testAggregationReportSuccessRate() async throws {
        let customDefaults = UserDefaults(suiteName: "SuccessRateTests.Aggregation") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "SuccessRateTests.Aggregation")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create comprehensive test data for aggregation
        let events = [
            // Task executions for aggregation: 7 successful, 3 failed, 2 expired = 12 total executions
            
            // Successful executions
            createTestEvent(taskId: "task-1", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-1200)),
            createTestEvent(taskId: "task-1", type: .taskExecutionCompleted, success: true, duration: 2.0, timestamp: Date().addingTimeInterval(-1198)),
            
            createTestEvent(taskId: "task-2", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-1000)),
            createTestEvent(taskId: "task-2", type: .taskExecutionCompleted, success: true, duration: 1.5, timestamp: Date().addingTimeInterval(-998.5)),
            
            createTestEvent(taskId: "task-3", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-900)),
            createTestEvent(taskId: "task-3", type: .taskExecutionCompleted, success: true, duration: 3.2, timestamp: Date().addingTimeInterval(-896.8)),
            
            createTestEvent(taskId: "task-4", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-800)),
            createTestEvent(taskId: "task-4", type: .taskExecutionCompleted, success: true, duration: 1.8, timestamp: Date().addingTimeInterval(-798.2)),
            
            createTestEvent(taskId: "task-5", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-700)),
            createTestEvent(taskId: "task-5", type: .taskExecutionCompleted, success: true, duration: 4.1, timestamp: Date().addingTimeInterval(-695.9)),
            
            createTestEvent(taskId: "task-6", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-600)),
            createTestEvent(taskId: "task-6", type: .taskExecutionCompleted, success: true, duration: 2.7, timestamp: Date().addingTimeInterval(-597.3)),
            
            createTestEvent(taskId: "task-7", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-500)),
            createTestEvent(taskId: "task-7", type: .taskExecutionCompleted, success: true, duration: 1.9, timestamp: Date().addingTimeInterval(-498.1)),
            
            // Failed executions
            createTestEvent(taskId: "task-8", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-400)),
            createTestEvent(taskId: "task-8", type: .taskExecutionCompleted, success: false, duration: 0.5, timestamp: Date().addingTimeInterval(-399.5)),
            
            createTestEvent(taskId: "task-9", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-300)),
            createTestEvent(taskId: "task-9", type: .taskExecutionCompleted, success: false, duration: 1.2, timestamp: Date().addingTimeInterval(-298.8)),
            
            createTestEvent(taskId: "task-10", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-200)),
            createTestEvent(taskId: "task-10", type: .taskExecutionCompleted, success: false, duration: 2.1, timestamp: Date().addingTimeInterval(-197.9)),
            
            // Expired executions
            createTestEvent(taskId: "task-11", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-150)),
            createTestEvent(taskId: "task-11", type: .taskExpired, success: false, timestamp: Date().addingTimeInterval(-120)),
            
            createTestEvent(taskId: "task-12", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-100)),
            createTestEvent(taskId: "task-12", type: .taskExpired, success: false, timestamp: Date().addingTimeInterval(-70))
        ]
        
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let statistics = dataStore.generateStatistics()
        
        // Create task metrics summary using corrected logic
        let taskMetricsSummary = TaskMetricsSummary(
            totalTasksScheduled: 0, // Not testing scheduling
            totalTasksExecuted: statistics.totalTasksExecuted,
            totalTasksCompleted: statistics.totalTasksCompleted,
            totalTasksFailed: statistics.totalTasksFailed,
            totalTasksExpired: statistics.totalTasksExpired,
            averageExecutionDuration: statistics.averageExecutionTime,
            averageSchedulingLatency: 0.0, // Not testing latency
            executionTimeDistribution: [:], // Not testing distribution
            hourlyExecutionPattern: statistics.executionsByHour
        )
        
        #expect(statistics.totalTasksExecuted == 12, "Should have 12 executed tasks")
        #expect(statistics.totalTasksCompleted == 10, "Should have 10 completed tasks (7 successful + 3 failed)")
        #expect(statistics.totalTasksFailed == 5, "Should have 5 failed tasks (3 failed + 2 expired)")
        #expect(statistics.totalTasksExpired == 2, "Should have 2 expired tasks")
        
        // Expected success rate: 7 successful / 12 executed = 0.583... (58.3%)
        let expectedSuccessRate = 7.0 / 12.0
        #expect(abs(statistics.successRate - expectedSuccessRate) < 0.001, 
               "Statistics success rate should be ~58.3% (7/12), got \(statistics.successRate)")
        
        #expect(abs(taskMetricsSummary.successRate - expectedSuccessRate) < 0.001,
               "Task metrics summary success rate should be ~58.3% (7/12), got \(taskMetricsSummary.successRate)")
    }
    
    // MARK: - Test Helper Functions
    
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
            metadata: ["test": "success_rate_test"],
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