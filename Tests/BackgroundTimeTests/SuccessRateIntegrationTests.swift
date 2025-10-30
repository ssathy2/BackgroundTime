//
//  SuccessRateIntegrationTests.swift
//  BackgroundTimeTests
//
//  Created by AI Assistant on 10/04/25.
//

import Testing
import Foundation
import SwiftUI
@testable import BackgroundTime

// MARK: - Success Rate Integration Tests

@Suite("Success Rate Integration Tests")
@MainActor
struct SuccessRateIntegrationTests {
    
    @Test("Complete Success Rate Flow Integration")
    func testCompleteSuccessRateFlowIntegration() async throws {
        // Create isolated test environment
        let customDefaults = UserDefaults(suiteName: "SuccessRateIntegration.CompleteFlow") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "SuccessRateIntegration.CompleteFlow")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Simulate realistic task execution scenarios
        // Total: 10 executions, 7 successful, 2 failed, 1 expired = 70% success rate
        let taskScenarios = [
            ("sync-task", true, 1.2),       // Success
            ("upload-task", true, 2.5),     // Success  
            ("download-task", false, 0.5),  // Failed
            ("backup-task", true, 4.1),     // Success
            ("cleanup-task", true, 0.8),    // Success
            ("heavy-task", false, 30.0),    // Failed
            ("quick-task", true, 0.3),      // Success
            ("data-sync", true, 1.9),       // Success
            ("image-proc", true, 5.2),      // Success
            ("timeout-task", nil, nil)      // Expired (no completion, just expiry)
        ]
        
        // Record all task executions
        for (index, (taskId, success, duration)) in taskScenarios.enumerated() {
            let timestamp = Date().addingTimeInterval(-Double(1000 - index * 100))
            
            // Always record execution start
            let startEvent = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: taskId,
                type: .taskExecutionStarted,
                timestamp: timestamp,
                duration: nil,
                success: true,
                errorMessage: nil,
                metadata: ["execution_index": String(index)],
                systemInfo: createTestSystemInfo()
            )
            dataStore.recordEvent(startEvent)
            
            // Record completion or expiry
            if let success = success, let duration = duration {
                let endEvent = BackgroundTaskEvent(
                    id: UUID(),
                    taskIdentifier: taskId,
                    type: .taskExecutionCompleted,
                    timestamp: timestamp.addingTimeInterval(duration),
                    duration: duration,
                    success: success,
                    errorMessage: success ? nil : "Test failure for \(taskId)",
                    metadata: ["execution_index": String(index)],
                    systemInfo: createTestSystemInfo()
                )
                dataStore.recordEvent(endEvent)
            } else {
                // Expired task
                let expiredEvent = BackgroundTaskEvent(
                    id: UUID(),
                    taskIdentifier: taskId,
                    type: .taskExpired,
                    timestamp: timestamp.addingTimeInterval(30.0),
                    duration: nil,
                    success: false,
                    errorMessage: "Task expired",
                    metadata: ["execution_index": String(index)],
                    systemInfo: createTestSystemInfo()
                )
                dataStore.recordEvent(expiredEvent)
            }
        }
        
        // Test 1: Data Store Statistics
        let dataStoreStats = dataStore.generateStatistics()
        #expect(dataStoreStats.totalTasksExecuted == 10, "Data store should report 10 executed tasks")
        #expect(dataStoreStats.totalTasksCompleted == 7, "Data store should report 7 successfully completed tasks")
        #expect(dataStoreStats.totalTasksFailed == 3, "Data store should report 3 failed tasks (2 failed + 1 expired)")
        #expect(dataStoreStats.totalTasksExpired == 1, "Data store should report 1 expired task")
        
        // Expected success rate: 7 successful out of 10 executed = 70%
        #expect(abs(dataStoreStats.successRate - 0.7) < 0.001, 
               "Data store success rate should be 70%, got \(dataStoreStats.successRate)")
        
        // Test 2: Individual Task Performance Metrics
        let uniqueTaskIds = Set(taskScenarios.map { $0.0 })
        for taskId in uniqueTaskIds {
            if let taskMetrics = dataStore.getTaskPerformanceMetrics(for: taskId) {
                #expect(taskMetrics.totalExecuted == 1, "Each task should have 1 execution")
                #expect(taskMetrics.successRate >= 0.0 && taskMetrics.successRate <= 1.0, 
                       "Task \(taskId) success rate should be between 0 and 1")
            }
        }
        
        // Test 3: Dashboard View Model Integration
        let dashboardViewModel = DashboardViewModel(dataStore: dataStore)
        await dashboardViewModel.loadData(for: .all, forceReload: true)
        
        #expect(dashboardViewModel.statistics != nil, "Dashboard should have statistics")
        guard let dashboardStats = dashboardViewModel.statistics else { return }
        
        #expect(dashboardStats.totalTasksExecuted == 10, "Dashboard should show 10 executed tasks")
        #expect(abs(dashboardStats.successRate - 0.7) < 0.001, 
               "Dashboard success rate should be 70%, got \(dashboardStats.successRate)")
        
        // Test 4: Task Metrics in Dashboard
        #expect(dashboardViewModel.taskMetrics.count == uniqueTaskIds.count, 
               "Dashboard should have metrics for all unique tasks")
        
        for taskMetric in dashboardViewModel.taskMetrics {
            #expect(taskMetric.successRate >= 0.0 && taskMetric.successRate <= 1.0,
                   "Task \(taskMetric.taskIdentifier) success rate should be valid")
        }
        
        // Test 5: BackgroundTime SDK Integration
        let sdkStats = BackgroundTime.shared.getCurrentStats()
        // Note: SDK stats may include additional events from initialization, so we check bounds
        #expect(sdkStats.successRate >= 0.0 && sdkStats.successRate <= 1.0, 
               "SDK success rate should be between 0 and 1")
        
        // Test 6: Success Rate Consistency Across Time Ranges
        await dashboardViewModel.loadData(for: .last24Hours, forceReload: true)
        let last24hStats = dashboardViewModel.statistics!
        
        await dashboardViewModel.loadData(for: .all, forceReload: true)
        let allTimeStats = dashboardViewModel.statistics!
        
        // Both should be the same since all events are recent
        #expect(last24hStats.totalTasksExecuted == allTimeStats.totalTasksExecuted,
               "24h and all-time executed counts should match for recent data")
        #expect(abs(last24hStats.successRate - allTimeStats.successRate) < 0.001,
               "24h and all-time success rates should match for recent data")
    }
    
    @Test("Edge Case Success Rate Integration")
    func testEdgeCaseSuccessRateIntegration() async throws {
        let customDefaults = UserDefaults(suiteName: "SuccessRateIntegration.EdgeCases") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "SuccessRateIntegration.EdgeCases")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Test edge case: Only completion events, no execution start events
        let completionOnlyEvents = [
            BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: "completion-only-success",
                type: .taskExecutionCompleted,
                timestamp: Date().addingTimeInterval(-100),
                duration: 2.0,
                success: true,
                errorMessage: nil,
                metadata: [:],
                systemInfo: createTestSystemInfo()
            ),
            BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: "completion-only-failed",
                type: .taskExecutionCompleted,
                timestamp: Date().addingTimeInterval(-80),
                duration: 1.0,
                success: false,
                errorMessage: "Completion only failure",
                metadata: [:],
                systemInfo: createTestSystemInfo()
            )
        ]
        
        for event in completionOnlyEvents {
            dataStore.recordEvent(event)
        }
        
        let edgeCaseStats = dataStore.generateStatistics()
        
        // Should infer execution count from completion events
        #expect(edgeCaseStats.totalTasksExecuted == 2, "Should infer 2 executed tasks from completion events")
        #expect(edgeCaseStats.totalTasksCompleted == 1, "Should report 1 successfully completed task")
        #expect(edgeCaseStats.totalTasksFailed == 1, "Should report 1 failed task")
        
        // Expected success rate: 1 successful out of 2 executed = 50%
        #expect(abs(edgeCaseStats.successRate - 0.5) < 0.001,
               "Edge case success rate should be 50%, got \(edgeCaseStats.successRate)")
        
        // Test dashboard with edge case data
        let edgeCaseDashboard = DashboardViewModel(dataStore: dataStore)
        await edgeCaseDashboard.loadData(for: .all, forceReload: true)
        
        #expect(edgeCaseDashboard.statistics?.successRate == edgeCaseStats.successRate,
               "Dashboard should match data store success rate for edge cases")
    }
    
    @Test("Time Range Filtered Success Rate Integration")
    func testTimeRangeFilteredSuccessRateIntegration() async throws {
        let customDefaults = UserDefaults(suiteName: "SuccessRateIntegration.TimeRange") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "SuccessRateIntegration.TimeRange")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        let now = Date()
        
        // Create events across different time periods with different success rates
        let timeBasedScenarios = [
            // 3 days ago: 100% success rate (2/2)
            ("old-task-1", now.addingTimeInterval(-3 * 24 * 3600), true, 1.0),
            ("old-task-2", now.addingTimeInterval(-3 * 24 * 3600 + 100), true, 1.5),
            
            // 12 hours ago: 50% success rate (1/2)
            ("medium-task-1", now.addingTimeInterval(-12 * 3600), true, 2.0),
            ("medium-task-2", now.addingTimeInterval(-12 * 3600 + 100), false, 1.0),
            
            // 2 hours ago: 33% success rate (1/3)
            ("recent-task-1", now.addingTimeInterval(-2 * 3600), false, 0.5),
            ("recent-task-2", now.addingTimeInterval(-2 * 3600 + 100), false, 1.2),
            ("recent-task-3", now.addingTimeInterval(-2 * 3600 + 200), true, 1.8),
        ]
        
        for (taskId, timestamp, success, duration) in timeBasedScenarios {
            let startEvent = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: taskId,
                type: .taskExecutionStarted,
                timestamp: timestamp,
                duration: nil,
                success: true,
                errorMessage: nil,
                metadata: [:],
                systemInfo: createTestSystemInfo()
            )
            dataStore.recordEvent(startEvent)
            
            let endEvent = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: taskId,
                type: .taskExecutionCompleted,
                timestamp: timestamp.addingTimeInterval(duration),
                duration: duration,
                success: success,
                errorMessage: success ? nil : "Test failure",
                metadata: [:],
                systemInfo: createTestSystemInfo()
            )
            dataStore.recordEvent(endEvent)
        }
        
        let dashboard = DashboardViewModel(dataStore: dataStore)
        
        // Test different time ranges
        await dashboard.loadData(for: .all, forceReload: true)
        let allStats = dashboard.statistics!
        #expect(allStats.totalTasksExecuted == 7, "All time should show 7 executed tasks")
        // Expected: 4 successful out of 7 = 57.1%
        #expect(abs(allStats.successRate - (4.0/7.0)) < 0.001,
               "All time success rate should be ~57.1%, got \(allStats.successRate)")
        
        await dashboard.loadData(for: .last24Hours, forceReload: true)
        let last24hStats = dashboard.statistics!
        #expect(last24hStats.totalTasksExecuted == 5, "Last 24h should show 5 executed tasks")
        // Expected: 2 successful out of 5 = 40%
        #expect(abs(last24hStats.successRate - 0.4) < 0.001,
               "Last 24h success rate should be 40%, got \(last24hStats.successRate)")
        
        await dashboard.loadData(for: .last6Hours, forceReload: true)
        let last6hStats = dashboard.statistics!
        #expect(last6hStats.totalTasksExecuted == 3, "Last 6h should show 3 executed tasks")
        // Expected: 1 successful out of 3 = 33.3%
        #expect(abs(last6hStats.successRate - (1.0/3.0)) < 0.001,
               "Last 6h success rate should be ~33.3%, got \(last6hStats.successRate)")
    }
    
    @Test("Success Rate with Mixed Event Types Integration")
    func testSuccessRateWithMixedEventTypesIntegration() async throws {
        let customDefaults = UserDefaults(suiteName: "SuccessRateIntegration.MixedTypes") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "SuccessRateIntegration.MixedTypes")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create complex scenario with various event types
        let mixedEvents = [
            // Scheduled events (shouldn't affect success rate calculation)
            BackgroundTaskEvent(id: UUID(), taskIdentifier: "task-1", type: .taskScheduled, 
                              timestamp: Date().addingTimeInterval(-500), duration: nil, success: true,
                              errorMessage: nil, metadata: [:], systemInfo: createTestSystemInfo()),
            BackgroundTaskEvent(id: UUID(), taskIdentifier: "task-2", type: .taskScheduled, 
                              timestamp: Date().addingTimeInterval(-490), duration: nil, success: true,
                              errorMessage: nil, metadata: [:], systemInfo: createTestSystemInfo()),
            
            // Regular execution flow: started -> completed (success)
            BackgroundTaskEvent(id: UUID(), taskIdentifier: "task-1", type: .taskExecutionStarted,
                              timestamp: Date().addingTimeInterval(-400), duration: nil, success: true,
                              errorMessage: nil, metadata: [:], systemInfo: createTestSystemInfo()),
            BackgroundTaskEvent(id: UUID(), taskIdentifier: "task-1", type: .taskExecutionCompleted,
                              timestamp: Date().addingTimeInterval(-398), duration: 2.0, success: true,
                              errorMessage: nil, metadata: [:], systemInfo: createTestSystemInfo()),
            
            // Execution flow: started -> completed (failed)
            BackgroundTaskEvent(id: UUID(), taskIdentifier: "task-2", type: .taskExecutionStarted,
                              timestamp: Date().addingTimeInterval(-300), duration: nil, success: true,
                              errorMessage: nil, metadata: [:], systemInfo: createTestSystemInfo()),
            BackgroundTaskEvent(id: UUID(), taskIdentifier: "task-2", type: .taskExecutionCompleted,
                              timestamp: Date().addingTimeInterval(-299), duration: 1.0, success: false,
                              errorMessage: "Task 2 failed", metadata: [:], systemInfo: createTestSystemInfo()),
            
            // Execution flow: started -> expired
            BackgroundTaskEvent(id: UUID(), taskIdentifier: "task-3", type: .taskExecutionStarted,
                              timestamp: Date().addingTimeInterval(-200), duration: nil, success: true,
                              errorMessage: nil, metadata: [:], systemInfo: createTestSystemInfo()),
            BackgroundTaskEvent(id: UUID(), taskIdentifier: "task-3", type: .taskExpired,
                              timestamp: Date().addingTimeInterval(-170), duration: nil, success: false,
                              errorMessage: "Task 3 expired", metadata: [:], systemInfo: createTestSystemInfo()),
            
            // Direct failed event (no start event)
            BackgroundTaskEvent(id: UUID(), taskIdentifier: "task-4", type: .taskFailed,
                              timestamp: Date().addingTimeInterval(-100), duration: nil, success: false,
                              errorMessage: "Task 4 direct failure", metadata: [:], systemInfo: createTestSystemInfo()),
            
            // App lifecycle events (shouldn't affect success rate)
            BackgroundTaskEvent(id: UUID(), taskIdentifier: "SDK_EVENT", type: .appEnteredBackground,
                              timestamp: Date().addingTimeInterval(-50), duration: nil, success: true,
                              errorMessage: nil, metadata: [:], systemInfo: createTestSystemInfo())
        ]
        
        for event in mixedEvents {
            dataStore.recordEvent(event)
        }
        
        let mixedStats = dataStore.generateStatistics()
        
        // Should count:
        // - 3 execution started events = 3 executed tasks
        // - 1 successful completion (task-1)
        // - 1 failed completion (task-2)  
        // - 1 expired task (task-3)
        // - task-4 direct failure shouldn't count as executed since no start event
        
        #expect(mixedStats.totalTasksExecuted == 3, "Should count 3 executed tasks (with start events)")
        #expect(mixedStats.totalTasksCompleted == 1, "Should count 1 successfully completed task")
        #expect(mixedStats.totalTasksFailed == 3, "Should count 3 failed tasks (1 failed completion + 1 expired + 1 direct failure)")
        #expect(mixedStats.totalTasksExpired == 1, "Should count 1 expired task")
        #expect(mixedStats.totalTasksScheduled == 2, "Should count 2 scheduled tasks")
        
        // Success rate: 1 successful out of 3 executed = 33.3%
        #expect(abs(mixedStats.successRate - (1.0/3.0)) < 0.001,
               "Mixed events success rate should be ~33.3%, got \(mixedStats.successRate)")
        
        // Test dashboard integration with mixed events
        let mixedDashboard = DashboardViewModel(dataStore: dataStore)
        await mixedDashboard.loadData(for: .all, forceReload: true)
        
        #expect(mixedDashboard.statistics?.successRate == mixedStats.successRate,
               "Dashboard should match data store success rate for mixed events")
        
        // Verify individual task metrics handle mixed scenarios correctly
        let taskMetrics = mixedDashboard.taskMetrics
        
        // Task 1 should have 100% success rate (1 successful execution)
        if let task1Metrics = taskMetrics.first(where: { $0.taskIdentifier == "task-1" }) {
            #expect(abs(task1Metrics.successRate - 1.0) < 0.001,
                   "Task 1 should have 100% success rate, got \(task1Metrics.successRate)")
        }
        
        // Task 2 should have 0% success rate (1 failed execution)
        if let task2Metrics = taskMetrics.first(where: { $0.taskIdentifier == "task-2" }) {
            #expect(abs(task2Metrics.successRate - 0.0) < 0.001,
                   "Task 2 should have 0% success rate, got \(task2Metrics.successRate)")
        }
        
        // Task 3 should have 0% success rate (1 expired execution)
        if let task3Metrics = taskMetrics.first(where: { $0.taskIdentifier == "task-3" }) {
            #expect(abs(task3Metrics.successRate - 0.0) < 0.001,
                   "Task 3 should have 0% success rate, got \(task3Metrics.successRate)")
        }
    }
    
    // MARK: - Test Helper Functions
    
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
