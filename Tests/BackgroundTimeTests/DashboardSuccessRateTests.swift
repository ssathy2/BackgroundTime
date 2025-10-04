//
//  DashboardSuccessRateTests.swift
//  BackgroundTimeTests
//
//  Created by AI Assistant on 10/04/25.
//

import Testing
import Foundation
import SwiftUI
@testable import BackgroundTime

// MARK: - Dashboard Success Rate Display Tests

@Suite("Dashboard Success Rate Display Tests")
@MainActor
struct DashboardSuccessRateTests {
    
    @Test("Dashboard Success Rate Card Display")
    func testDashboardSuccessRateCardDisplay() async throws {
        // Create test data with known success rate
        let customDefaults = UserDefaults(suiteName: "DashboardSuccessRateTests.CardDisplay") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "DashboardSuccessRateTests.CardDisplay")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create events: 3 successful out of 4 total = 75% success rate
        let events = [
            createTestEvent(taskId: "task-1", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-1", type: .taskExecutionCompleted, success: true, duration: 2.0),
            
            createTestEvent(taskId: "task-2", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-2", type: .taskExecutionCompleted, success: false, duration: 1.0),
            
            createTestEvent(taskId: "task-3", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-3", type: .taskExecutionCompleted, success: true, duration: 1.5),
            
            createTestEvent(taskId: "task-4", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-4", type: .taskExecutionCompleted, success: true, duration: 3.0)
        ]
        
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let viewModel = DashboardViewModel(dataStore: dataStore)
        await viewModel.loadData(for: .last24Hours, forceReload: true)
        
        // Verify the data is correct in the view model
        #expect(viewModel.statistics != nil, "Dashboard should have statistics")
        
        guard let stats = viewModel.statistics else { return }
        
        #expect(stats.totalTasksExecuted == 4, "Should show 4 executed tasks")
        #expect(abs(stats.successRate - 0.75) < 0.001, "Success rate should be 75% (0.75)")
        
        // Create the overview tab view and verify it can be instantiated
        let overviewTab = OverviewTabView(viewModel: viewModel, selectedTimeRange: .last24Hours)
        #expect(overviewTab is OverviewTabView, "Overview tab should be created successfully")
        
        // Create a StatisticCard for success rate to verify it displays the right format
        let successRateCard = StatisticCard(
            title: "Success Rate",
            value: String(format: "%.1f%%", stats.successRate * 100),
            icon: "checkmark.circle.fill",
            color: .green
        )
        
        #expect(successRateCard is StatisticCard, "Success rate card should be created")
        
        // Verify the formatted value is correct
        let expectedValue = "75.0%"
        let actualValue = String(format: "%.1f%%", stats.successRate * 100)
        #expect(actualValue == expectedValue, "Formatted success rate should be '75.0%', got '\(actualValue)'")
    }
    
    @Test("Dashboard Performance Tab Success Rate Display")
    func testDashboardPerformanceTabSuccessRateDisplay() async throws {
        let customDefaults = UserDefaults(suiteName: "DashboardSuccessRateTests.PerformanceTab") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "DashboardSuccessRateTests.PerformanceTab")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create task executions with different success rates
        let events = [
            // high-success-task: 3/3 = 100%
            createTestEvent(taskId: "high-success-task", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-600)),
            createTestEvent(taskId: "high-success-task", type: .taskExecutionCompleted, success: true, duration: 1.0, timestamp: Date().addingTimeInterval(-599)),
            createTestEvent(taskId: "high-success-task", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-500)),
            createTestEvent(taskId: "high-success-task", type: .taskExecutionCompleted, success: true, duration: 1.2, timestamp: Date().addingTimeInterval(-498.8)),
            createTestEvent(taskId: "high-success-task", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-400)),
            createTestEvent(taskId: "high-success-task", type: .taskExecutionCompleted, success: true, duration: 0.8, timestamp: Date().addingTimeInterval(-399.2)),
            
            // medium-success-task: 2/3 = 66.7%
            createTestEvent(taskId: "medium-success-task", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-300)),
            createTestEvent(taskId: "medium-success-task", type: .taskExecutionCompleted, success: true, duration: 2.0, timestamp: Date().addingTimeInterval(-298)),
            createTestEvent(taskId: "medium-success-task", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-250)),
            createTestEvent(taskId: "medium-success-task", type: .taskExecutionCompleted, success: false, duration: 1.5, timestamp: Date().addingTimeInterval(-248.5)),
            createTestEvent(taskId: "medium-success-task", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-200)),
            createTestEvent(taskId: "medium-success-task", type: .taskExecutionCompleted, success: true, duration: 1.8, timestamp: Date().addingTimeInterval(-198.2)),
            
            // low-success-task: 0/2 = 0%
            createTestEvent(taskId: "low-success-task", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-150)),
            createTestEvent(taskId: "low-success-task", type: .taskExecutionCompleted, success: false, duration: 0.5, timestamp: Date().addingTimeInterval(-149.5)),
            createTestEvent(taskId: "low-success-task", type: .taskExecutionStarted, success: true, timestamp: Date().addingTimeInterval(-100)),
            createTestEvent(taskId: "low-success-task", type: .taskExpired, success: false, timestamp: Date().addingTimeInterval(-70))
        ]
        
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let viewModel = DashboardViewModel(dataStore: dataStore)
        await viewModel.loadData(for: .last24Hours, forceReload: true)
        
        // Verify task metrics are generated correctly
        #expect(viewModel.taskMetrics.count >= 3, "Should have at least 3 task metrics")
        
        // Test individual task metrics
        if let highSuccessTaskMetric = viewModel.taskMetrics.first(where: { $0.taskIdentifier == "high-success-task" }) {
            #expect(abs(highSuccessTaskMetric.successRate - 1.0) < 0.001, 
                   "High success task should have 100% success rate, got \(highSuccessTaskMetric.successRate)")
        }
        
        if let mediumSuccessTaskMetric = viewModel.taskMetrics.first(where: { $0.taskIdentifier == "medium-success-task" }) {
            let expectedRate = 2.0 / 3.0 // 66.7%
            #expect(abs(mediumSuccessTaskMetric.successRate - expectedRate) < 0.001,
                   "Medium success task should have ~66.7% success rate, got \(mediumSuccessTaskMetric.successRate)")
        }
        
        if let lowSuccessTaskMetric = viewModel.taskMetrics.first(where: { $0.taskIdentifier == "low-success-task" }) {
            #expect(abs(lowSuccessTaskMetric.successRate - 0.0) < 0.001,
                   "Low success task should have 0% success rate, got \(lowSuccessTaskMetric.successRate)")
        }
        
        // Create performance tab view and verify it can be instantiated
        let performanceTab = PerformanceTabView(viewModel: viewModel, selectedTimeRange: .last24Hours)
        #expect(performanceTab is PerformanceTabView, "Performance tab should be created successfully")
        
        // Test TaskMetricCard creation with different success rates
        for taskMetric in viewModel.taskMetrics {
            let taskCard = TaskMetricCard(metric: taskMetric)
            #expect(taskCard is TaskMetricCard, "Task metric card should be created for \(taskMetric.taskIdentifier)")
            
            // Verify success rate formatting
            let formattedRate = String(format: "%.1f%%", taskMetric.successRate * 100)
            #expect(formattedRate.contains("%"), "Formatted success rate should contain % symbol")
            #expect(taskMetric.successRate >= 0.0 && taskMetric.successRate <= 1.0, 
                   "Success rate should be between 0 and 1 for \(taskMetric.taskIdentifier)")
        }
    }
    
    @Test("Dashboard Zero Success Rate Handling")
    func testDashboardZeroSuccessRateHandling() async throws {
        let customDefaults = UserDefaults(suiteName: "DashboardSuccessRateTests.ZeroRate") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "DashboardSuccessRateTests.ZeroRate")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create all failed events
        let events = [
            createTestEvent(taskId: "always-fails", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "always-fails", type: .taskExecutionCompleted, success: false, duration: 1.0),
            
            createTestEvent(taskId: "always-expires", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "always-expires", type: .taskExpired, success: false),
        ]
        
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let viewModel = DashboardViewModel(dataStore: dataStore)
        await viewModel.loadData(for: .last24Hours, forceReload: true)
        
        #expect(viewModel.statistics != nil, "Dashboard should have statistics")
        
        guard let stats = viewModel.statistics else { return }
        
        #expect(stats.totalTasksExecuted == 2, "Should show 2 executed tasks")
        #expect(stats.successRate == 0.0, "Success rate should be 0.0")
        
        // Test that 0% success rate is formatted correctly
        let formattedRate = String(format: "%.1f%%", stats.successRate * 100)
        #expect(formattedRate == "0.0%", "Zero success rate should format as '0.0%', got '\(formattedRate)'")
        
        // Verify task-specific zero rates
        for taskMetric in viewModel.taskMetrics {
            #expect(taskMetric.successRate == 0.0, 
                   "All tasks should have 0% success rate, got \(taskMetric.successRate) for \(taskMetric.taskIdentifier)")
        }
    }
    
    @Test("Dashboard Perfect Success Rate Handling")
    func testDashboardPerfectSuccessRateHandling() async throws {
        let customDefaults = UserDefaults(suiteName: "DashboardSuccessRateTests.PerfectRate") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "DashboardSuccessRateTests.PerfectRate")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create all successful events
        let events = [
            createTestEvent(taskId: "perfect-task-1", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "perfect-task-1", type: .taskExecutionCompleted, success: true, duration: 1.0),
            
            createTestEvent(taskId: "perfect-task-2", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "perfect-task-2", type: .taskExecutionCompleted, success: true, duration: 2.5),
            
            createTestEvent(taskId: "perfect-task-3", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "perfect-task-3", type: .taskExecutionCompleted, success: true, duration: 0.8),
        ]
        
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let viewModel = DashboardViewModel(dataStore: dataStore)
        await viewModel.loadData(for: .last24Hours, forceReload: true)
        
        #expect(viewModel.statistics != nil, "Dashboard should have statistics")
        
        guard let stats = viewModel.statistics else { return }
        
        #expect(stats.totalTasksExecuted == 3, "Should show 3 executed tasks")
        #expect(stats.successRate == 1.0, "Success rate should be 1.0 (100%)")
        
        // Test that 100% success rate is formatted correctly
        let formattedRate = String(format: "%.1f%%", stats.successRate * 100)
        #expect(formattedRate == "100.0%", "Perfect success rate should format as '100.0%', got '\(formattedRate)'")
        
        // Verify task-specific perfect rates
        for taskMetric in viewModel.taskMetrics {
            #expect(taskMetric.successRate == 1.0, 
                   "All tasks should have 100% success rate, got \(taskMetric.successRate) for \(taskMetric.taskIdentifier)")
        }
    }
    
    @Test("Dashboard Success Rate with Time Range Filtering")
    func testDashboardSuccessRateWithTimeRangeFiltering() async throws {
        let customDefaults = UserDefaults(suiteName: "DashboardSuccessRateTests.TimeRange") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "DashboardSuccessRateTests.TimeRange")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        let now = Date()
        
        // Create events across different time periods
        let events = [
            // Events from 2 days ago (should be filtered out for last 24 hours)
            createTestEvent(taskId: "old-task", type: .taskExecutionStarted, success: true, 
                           timestamp: now.addingTimeInterval(-48 * 3600)), // 2 days ago
            createTestEvent(taskId: "old-task", type: .taskExecutionCompleted, success: false, duration: 1.0,
                           timestamp: now.addingTimeInterval(-48 * 3600 + 1)),
            
            // Events from 12 hours ago (should be included in last 24 hours)
            createTestEvent(taskId: "recent-task-1", type: .taskExecutionStarted, success: true,
                           timestamp: now.addingTimeInterval(-12 * 3600)), // 12 hours ago
            createTestEvent(taskId: "recent-task-1", type: .taskExecutionCompleted, success: true, duration: 2.0,
                           timestamp: now.addingTimeInterval(-12 * 3600 + 2)),
            
            createTestEvent(taskId: "recent-task-2", type: .taskExecutionStarted, success: true,
                           timestamp: now.addingTimeInterval(-6 * 3600)), // 6 hours ago
            createTestEvent(taskId: "recent-task-2", type: .taskExecutionCompleted, success: false, duration: 1.5,
                           timestamp: now.addingTimeInterval(-6 * 3600 + 1.5)),
            
            // Events from 1 hour ago (should be included in last 24 hours)
            createTestEvent(taskId: "very-recent-task", type: .taskExecutionStarted, success: true,
                           timestamp: now.addingTimeInterval(-3600)), // 1 hour ago
            createTestEvent(taskId: "very-recent-task", type: .taskExecutionCompleted, success: true, duration: 0.8,
                           timestamp: now.addingTimeInterval(-3600 + 0.8))
        ]
        
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let viewModel = DashboardViewModel(dataStore: dataStore)
        
        // Test last 24 hours filtering
        await viewModel.loadData(for: .last24Hours, forceReload: true)
        
        #expect(viewModel.statistics != nil, "Dashboard should have statistics for last 24 hours")
        
        guard let last24hStats = viewModel.statistics else { return }
        
        // Should include 3 recent tasks: 2 successful, 1 failed = 66.7% success rate
        #expect(last24hStats.totalTasksExecuted == 3, "Should show 3 executed tasks in last 24 hours")
        let expected24hRate = 2.0 / 3.0 // 66.7%
        #expect(abs(last24hStats.successRate - expected24hRate) < 0.001,
               "Success rate for last 24 hours should be ~66.7%, got \(last24hStats.successRate)")
        
        // Test all time filtering
        await viewModel.loadData(for: .all, forceReload: true)
        
        guard let allTimeStats = viewModel.statistics else { return }
        
        // Should include all 4 tasks: 2 successful, 2 failed = 50% success rate
        #expect(allTimeStats.totalTasksExecuted == 4, "Should show 4 executed tasks for all time")
        #expect(abs(allTimeStats.successRate - 0.5) < 0.001,
               "Success rate for all time should be 50%, got \(allTimeStats.successRate)")
        
        // Test 1 hour filtering
        await viewModel.loadData(for: .last1Hour, forceReload: true)
        
        guard let last1hStats = viewModel.statistics else { return }
        
        // Should include only 1 task: 1 successful = 100% success rate
        #expect(last1hStats.totalTasksExecuted == 1, "Should show 1 executed task in last hour")
        #expect(abs(last1hStats.successRate - 1.0) < 0.001,
               "Success rate for last hour should be 100%, got \(last1hStats.successRate)")
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
            metadata: ["test": "dashboard_success_rate_test"],
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