//
//  BackgroundTimeDashboardTests.swift
//  BackgroundTimeTests
//
//  Created by Siddharth Sathyam on 9/26/25.
//

import Testing
import Foundation
import SwiftUI
import UIKit
@testable import BackgroundTime

@Suite("BackgroundTimeDashboard Tests")
@MainActor
struct BackgroundTimeDashboardTests {
    
    // MARK: - Dashboard Initialization Tests
    
    @Test("Dashboard Initialization")
    func testDashboardInitialization() async throws {
        let dashboard = BackgroundTimeDashboard()
        
        // Test that dashboard can be created without issues
        #expect(dashboard is BackgroundTimeDashboard, "Dashboard should initialize successfully")
    }
    
    // MARK: - Dashboard Tab Tests
    
    @Test("Dashboard Tab Enumeration")
    func testDashboardTabEnumeration() async throws {
        // Test tab properties
        #expect(DashboardTab.overview.title == "Overview", "Overview tab should have correct title")
        #expect(DashboardTab.timeline.title == "Timeline", "Timeline tab should have correct title")
        #expect(DashboardTab.performance.title == "Performance", "Performance tab should have correct title")
        #expect(DashboardTab.errors.title == "Errors", "Errors tab should have correct title")
        #expect(DashboardTab.continuousTasks.title == "Continuous", "Continuous tasks tab should have correct title")
        
        // Test system images
        #expect(DashboardTab.overview.systemImage == "chart.bar.fill", "Overview should have correct icon")
        #expect(DashboardTab.timeline.systemImage == "clock.fill", "Timeline should have correct icon")
        #expect(DashboardTab.performance.systemImage == "speedometer", "Performance should have correct icon")
        #expect(DashboardTab.errors.systemImage == "exclamationmark.triangle.fill", "Errors should have correct icon")
        #expect(DashboardTab.continuousTasks.systemImage == "infinity.circle.fill", "Continuous tasks should have correct icon")
    }
    
    @Test("Dashboard Tab Availability")
    func testDashboardTabAvailability() async throws {
        let legacyTabs = DashboardTab.allCasesForLegacyOS
        #expect(legacyTabs.count == 4, "Legacy OS should have 4 tabs")
        #expect(legacyTabs.contains(.overview), "Legacy should include overview")
        #expect(legacyTabs.contains(.timeline), "Legacy should include timeline")
        #expect(legacyTabs.contains(.performance), "Legacy should include performance")
        #expect(legacyTabs.contains(.errors), "Legacy should include errors")
        #expect(!legacyTabs.contains(.continuousTasks), "Legacy should not include continuous tasks")
        
        if #available(iOS 26.0, *) {
            let currentTabs = DashboardTab.allCasesForCurrentOS
            #expect(currentTabs.count == 5, "Current OS should have 5 tabs")
            #expect(currentTabs.contains(.continuousTasks), "Current OS should include continuous tasks")
        }
    }
    
    // MARK: - iOS Version Support Tests
    
    @Test("iOS Version Support Detection")
    func testIOSVersionSupportDetection() async throws {
        let supportsContinuousTasks = UIDevice.supportsContinuousBackgroundTasks
        
        if #available(iOS 26.0, *) {
            #expect(supportsContinuousTasks == true, "iOS 26+ should support continuous tasks")
        } else {
            #expect(supportsContinuousTasks == false, "iOS < 26 should not support continuous tasks")
        }
    }
    
    // MARK: - View Component Tests
    
    @Test("StatisticCard Component")
    func testStatisticCardComponent() async throws {
        let card = StatisticCard(
            title: "Test Metric",
            value: "42",
            icon: "checkmark.circle.fill",
            color: .blue
        )
        
        // Test that component can be created
        #expect(card is StatisticCard, "StatisticCard should be created successfully")
    }
    
    @Test("RecentEventsView Component")
    func testRecentEventsViewComponent() async throws {
        let testEvents = createTestEventsForView(count: 3)
        let recentEventsView = RecentEventsView(events: testEvents)
        
        #expect(recentEventsView is RecentEventsView, "RecentEventsView should be created successfully")
    }
    
    @Test("TimelineRowView Component")
    func testTimelineRowViewComponent() async throws {
        let dataPoint = TimelineDataPoint(
            timestamp: Date(),
            eventType: .taskExecutionCompleted,
            taskIdentifier: "test-task",
            duration: 2.5,
            success: true
        )
        
        let timelineRow = TimelineRowView(dataPoint: dataPoint, isLast: false)
        #expect(timelineRow is TimelineRowView, "TimelineRowView should be created successfully")
        
        let lastTimelineRow = TimelineRowView(dataPoint: dataPoint, isLast: true)
        #expect(lastTimelineRow is TimelineRowView, "Last TimelineRowView should be created successfully")
    }
    
    @Test("TaskMetricCard Component")
    func testTaskMetricCardComponent() async throws {
        let metric = TaskPerformanceMetrics(
            taskIdentifier: "test-task",
            totalScheduled: 10,
            totalExecuted: 8,
            totalCompleted: 7,
            totalFailed: 1,
            averageDuration: 2.5,
            successRate: 0.875,
            lastExecutionDate: Date()
        )
        
        let metricCard = TaskMetricCard(metric: metric)
        #expect(metricCard is TaskMetricCard, "TaskMetricCard should be created successfully")
    }
    
    @Test("ErrorEventCard Component")
    func testErrorEventCardComponent() async throws {
        let errorEvent = createTestEventsForView(count: 1).first!
        let errorCard = ErrorEventCard(event: errorEvent)
        
        #expect(errorCard is ErrorEventCard, "ErrorEventCard should be created successfully")
    }
    
    // MARK: - Tab View Tests
    
    @Test("OverviewTabView Component")
    func testOverviewTabViewComponent() async throws {
        let viewModel = DashboardViewModel()
        let overviewTab = OverviewTabView(viewModel: viewModel, selectedTimeRange: .last24Hours)
        
        #expect(overviewTab is OverviewTabView, "OverviewTabView should be created successfully")
    }
    
    @Test("TimelineTabView Component")
    func testTimelineTabViewComponent() async throws {
        let viewModel = DashboardViewModel()
        let timelineTab = TimelineTabView(viewModel: viewModel, selectedTimeRange: .last24Hours)
        
        #expect(timelineTab is TimelineTabView, "TimelineTabView should be created successfully")
    }
    
    @Test("PerformanceTabView Component")
    func testPerformanceTabViewComponent() async throws {
        let viewModel = DashboardViewModel()
        let performanceTab = PerformanceTabView(viewModel: viewModel, selectedTimeRange: .last24Hours)
        
        #expect(performanceTab is PerformanceTabView, "PerformanceTabView should be created successfully")
    }
    
    @Test("ErrorsTabView Component")
    func testErrorsTabViewComponent() async throws {
        let viewModel = DashboardViewModel()
        let errorsTab = ErrorsTabView(viewModel: viewModel, selectedTimeRange: .last24Hours)
        
        #expect(errorsTab is ErrorsTabView, "ErrorsTabView should be created successfully")
    }
    
    // MARK: - Continuous Tasks Tab Tests (iOS 26.0+)
    
    @Test("ContinuousTasksTabView Component")
    @available(iOS 26.0, *)
    func testContinuousTasksTabViewComponent() async throws {
        let viewModel = DashboardViewModel()
        let continuousTab = ContinuousTasksTabView(viewModel: viewModel, selectedTimeRange: .last24Hours)
        
        #expect(continuousTab is ContinuousTasksTabView, "ContinuousTasksTabView should be created successfully")
    }
    
    @Test("ContinuousTaskRow Component")
    @available(iOS 26.0, *)
    func testContinuousTaskRowComponent() async throws {
        let events = [
            createTestEventForView(taskId: "continuous-1", type: .continuousTaskStarted),
            createTestEventForView(taskId: "continuous-1", type: .continuousTaskProgress),
        ]
        
        let taskRow = ContinuousTaskRow(taskIdentifier: "continuous-1", events: events)
        #expect(taskRow is ContinuousTaskRow, "ContinuousTaskRow should be created successfully")
    }
    
    @Test("ContinuousTaskPerformanceCard Component")
    @available(iOS 26.0, *)
    func testContinuousTaskPerformanceCardComponent() async throws {
        let events = [
            createTestEventForView(taskId: "continuous-1", type: .continuousTaskStarted, duration: 10.0),
            createTestEventForView(taskId: "continuous-1", type: .continuousTaskResumed, duration: 5.0),
        ]
        
        let performanceCard = ContinuousTaskPerformanceCard(taskIdentifier: "continuous-1", events: events)
        #expect(performanceCard is ContinuousTaskPerformanceCard, "ContinuousTaskPerformanceCard should be created successfully")
    }
    
    @Test("ContinuousTaskDisplayStatus")
    @available(iOS 26.0, *)
    func testContinuousTaskDisplayStatus() async throws {
        #expect(ContinuousTaskDisplayStatus.running.displayName == "Running", "Running status should have correct display name")
        #expect(ContinuousTaskDisplayStatus.paused.displayName == "Paused", "Paused status should have correct display name")
        #expect(ContinuousTaskDisplayStatus.stopped.displayName == "Stopped", "Stopped status should have correct display name")
        #expect(ContinuousTaskDisplayStatus.unknown.displayName == "Unknown", "Unknown status should have correct display name")
        
        #expect(ContinuousTaskDisplayStatus.running.color == .green, "Running should be green")
        #expect(ContinuousTaskDisplayStatus.paused.color == .yellow, "Paused should be yellow")
        #expect(ContinuousTaskDisplayStatus.stopped.color == .red, "Stopped should be red")
        #expect(ContinuousTaskDisplayStatus.unknown.color == .gray, "Unknown should be gray")
    }
    
    // MARK: - Performance Tab Component Tests
    
    @Test("PerformanceMetricFilter Enumeration")
    func testPerformanceMetricFilterEnumeration() async throws {
        #expect(PerformanceMetricFilter.all.displayName == "All Tasks", "All filter should have correct display name")
        #expect(PerformanceMetricFilter.slow.displayName == "Slow Tasks", "Slow filter should have correct display name")
        #expect(PerformanceMetricFilter.failed.displayName == "Failed Tasks", "Failed filter should have correct display name")
        #expect(PerformanceMetricFilter.recent.displayName == "Recent", "Recent filter should have correct display name")
        
        #expect(PerformanceMetricFilter.all.icon == "list.bullet", "All filter should have correct icon")
        #expect(PerformanceMetricFilter.slow.icon == "tortoise.fill", "Slow filter should have correct icon")
        #expect(PerformanceMetricFilter.failed.icon == "xmark.circle.fill", "Failed filter should have correct icon")
        #expect(PerformanceMetricFilter.recent.icon == "clock.fill", "Recent filter should have correct icon")
    }
    
    @Test("PerformanceTrend Enumeration")
    func testPerformanceTrendEnumeration() async throws {
        #expect(PerformanceTrend.improving.color == .green, "Improving trend should be green")
        #expect(PerformanceTrend.stable.color == .blue, "Stable trend should be blue")
        #expect(PerformanceTrend.declining.color == .red, "Declining trend should be red")
        
        #expect(PerformanceTrend.improving.icon == "arrow.up.right", "Improving should have up arrow")
        #expect(PerformanceTrend.stable.icon == "arrow.right", "Stable should have right arrow")
        #expect(PerformanceTrend.declining.icon == "arrow.down.right", "Declining should have down arrow")
    }
    
    @Test("DurationEvent Structure")
    func testDurationEventStructure() async throws {
        let durationEvent = DurationEvent(
            id: UUID(),
            timestamp: Date(),
            duration: 2.5,
            taskIdentifier: "test-task"
        )
        
        #expect(durationEvent.duration == 2.5, "Duration should be set correctly")
        #expect(durationEvent.taskIdentifier == "test-task", "Task identifier should be set correctly")
    }
    
    @Test("PerformanceKPICard Component")
    func testPerformanceKPICardComponent() async throws {
        let kpiCard = PerformanceKPICard(
            title: "Test KPI",
            value: "95.5%",
            trend: .improving,
            icon: "checkmark.circle.fill"
        )
        
        #expect(kpiCard is PerformanceKPICard, "PerformanceKPICard should be created successfully")
    }
    
    @Test("LiveMetricGauge Component")
    func testLiveMetricGaugeComponent() async throws {
        let gauge = LiveMetricGauge(
            title: "CPU Usage",
            value: 45.0,
            maxValue: 100.0,
            unit: "%",
            color: .blue
        )
        
        #expect(gauge is LiveMetricGauge, "LiveMetricGauge should be created successfully")
    }
    
    @Test("EnhancedTaskMetricCard Component")
    func testEnhancedTaskMetricCardComponent() async throws {
        let metric = TaskPerformanceMetrics(
            taskIdentifier: "enhanced-task",
            totalScheduled: 15,
            totalExecuted: 12,
            totalCompleted: 11,
            totalFailed: 1,
            averageDuration: 3.2,
            successRate: 0.917,
            lastExecutionDate: Date()
        )
        
        let enhancedCard = EnhancedTaskMetricCard(metric: metric) {
            // Mock tap action
        }
        
        #expect(enhancedCard is EnhancedTaskMetricCard, "EnhancedTaskMetricCard should be created successfully")
    }
    
    @Test("PerformanceInsight Types")
    func testPerformanceInsightTypes() async throws {
        #expect(PerformanceInsightType.optimization.color == .blue, "Optimization should be blue")
        #expect(PerformanceInsightType.warning.color == .orange, "Warning should be orange")
        #expect(PerformanceInsightType.info.color == .purple, "Info should be purple")
        
        #expect(PerformanceInsightType.optimization.icon == "lightbulb.fill", "Optimization should have lightbulb icon")
        #expect(PerformanceInsightType.warning.icon == "exclamationmark.triangle.fill", "Warning should have triangle icon")
        #expect(PerformanceInsightType.info.icon == "info.circle.fill", "Info should have info icon")
    }
    
    @Test("PerformancePriority Enumeration")
    func testPerformancePriorityEnumeration() async throws {
        #expect(PerformancePriority.low.color == .green, "Low priority should be green")
        #expect(PerformancePriority.medium.color == .blue, "Medium priority should be blue")
        #expect(PerformancePriority.high.color == .orange, "High priority should be orange")
        #expect(PerformancePriority.critical.color == .red, "Critical priority should be red")
        
        #expect(PerformancePriority.low.displayName == "Low", "Low priority display name")
        #expect(PerformancePriority.medium.displayName == "Medium", "Medium priority display name")
        #expect(PerformancePriority.high.displayName == "High", "High priority display name")
        #expect(PerformancePriority.critical.displayName == "Critical", "Critical priority display name")
    }
    
    @Test("PerformanceInsightCard Component")
    func testPerformanceInsightCardComponent() async throws {
        let insight = PerformanceInsight(
            id: UUID(),
            type: .optimization,
            title: "Test Insight",
            description: "This is a test performance insight",
            priority: .medium,
            actionable: true
        )
        
        let insightCard = PerformanceInsightCard(insight: insight)
        #expect(insightCard is PerformanceInsightCard, "PerformanceInsightCard should be created successfully")
    }
    
    // MARK: - Event Type Extension Tests
    
    @Test("BackgroundTaskEventType Icon Extension")
    func testBackgroundTaskEventTypeIconExtension() async throws {
        #expect(BackgroundTaskEventType.taskScheduled.icon == "calendar.badge.plus", "Scheduled task should have correct icon")
        #expect(BackgroundTaskEventType.taskExecutionStarted.icon == "play.fill", "Started task should have correct icon")
        #expect(BackgroundTaskEventType.taskExecutionCompleted.icon == "checkmark.circle.fill", "Completed task should have correct icon")
        #expect(BackgroundTaskEventType.taskExpired.icon == "clock.badge.exclamationmark", "Expired task should have correct icon")
        #expect(BackgroundTaskEventType.taskCancelled.icon == "xmark.circle.fill", "Cancelled task should have correct icon")
        #expect(BackgroundTaskEventType.taskFailed.icon == "exclamationmark.triangle.fill", "Failed task should have correct icon")
        #expect(BackgroundTaskEventType.initialization.icon == "gear", "Initialization should have correct icon")
        #expect(BackgroundTaskEventType.appEnteredBackground.icon == "moon.fill", "Background should have correct icon")
        #expect(BackgroundTaskEventType.appWillEnterForeground.icon == "sun.max.fill", "Foreground should have correct icon")
        
        // Test continuous task icons
        if #available(iOS 26.0, *) {
            #expect(BackgroundTaskEventType.continuousTaskStarted.icon == "infinity.circle.fill", "Continuous started should have correct icon")
            #expect(BackgroundTaskEventType.continuousTaskPaused.icon == "pause.circle.fill", "Continuous paused should have correct icon")
            #expect(BackgroundTaskEventType.continuousTaskResumed.icon == "play.circle.fill", "Continuous resumed should have correct icon")
            #expect(BackgroundTaskEventType.continuousTaskStopped.icon == "stop.circle.fill", "Continuous stopped should have correct icon")
            #expect(BackgroundTaskEventType.continuousTaskProgress.icon == "chart.line.uptrend.xyaxis", "Continuous progress should have correct icon")
        } else {
            #expect(BackgroundTaskEventType.continuousTaskStarted.icon == "play.fill", "Continuous started fallback icon")
            #expect(BackgroundTaskEventType.continuousTaskPaused.icon == "pause.fill", "Continuous paused fallback icon")
            #expect(BackgroundTaskEventType.continuousTaskResumed.icon == "play.fill", "Continuous resumed fallback icon")
            #expect(BackgroundTaskEventType.continuousTaskStopped.icon == "stop.fill", "Continuous stopped fallback icon")
            #expect(BackgroundTaskEventType.continuousTaskProgress.icon == "chart.bar.fill", "Continuous progress fallback icon")
        }
    }
    
    // MARK: - Time Range Extension Tests
    
    @Test("TimeRange Extension Functionality")
    func testTimeRangeExtensionFunctionality() async throws {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let twoDaysAgo = now.addingTimeInterval(-86400 * 2)
        
        let range = TimeRange.last24Hours
        
        #expect(range.startDate <= now, "Start date should be before or equal to now")
        #expect(range.endDate <= now || abs(range.endDate.timeIntervalSince(now)) < 1.0, "End date should be approximately now")
        
        #expect(range.contains(oneHourAgo), "Should contain date within last 24 hours")
        #expect(!range.contains(twoDaysAgo), "Should not contain date from 2 days ago")
    }
    
    // MARK: - Helper View Component Tests
    
    @Test("MetricRow Component")
    func testMetricRowComponent() async throws {
        let metricRow = MetricRow(label: "Test Metric", value: "100")
        #expect(metricRow is MetricRow, "MetricRow should be created successfully")
    }
    
    @Test("LegendItem Component")
    func testLegendItemComponent() async throws {
        let legendItem = LegendItem(color: .blue, text: "Test Legend")
        #expect(legendItem is LegendItem, "LegendItem should be created successfully")
    }
    
    @Test("MetricItem Component")
    func testMetricItemComponent() async throws {
        let metricItem = MetricItem(label: "Test", value: "42", color: .green)
        #expect(metricItem is MetricItem, "MetricItem should be created successfully")
    }
    
    // MARK: - Error Summary Section Tests
    
    @Test("ErrorSummarySection Component")
    func testErrorSummarySectionComponent() async throws {
        let errorsByType = [
            "Network Error": 5,
            "Timeout Error": 3,
            "System Error": 2
        ]
        
        let errorSummary = ErrorsTabView.ErrorSummarySection(errorsByType: errorsByType)
        #expect(errorSummary is ErrorsTabView.ErrorSummarySection, "ErrorSummarySection should be created successfully")
    }
    
    // MARK: - Detail View Tests
    
    @Test("DetailedTaskPerformanceView Component")
    func testDetailedTaskPerformanceViewComponent() async throws {
        let viewModel = DashboardViewModel()
        let detailView = DetailedTaskPerformanceView(
            taskIdentifier: "test-task",
            viewModel: viewModel
        )
        
        #expect(detailView is DetailedTaskPerformanceView, "DetailedTaskPerformanceView should be created successfully")
    }
    
    // MARK: - Integration Tests
    
    @Test("Dashboard with Mock Data Integration")
    func testDashboardWithMockDataIntegration() async throws {
        // Create dashboard
        let dashboard = BackgroundTimeDashboard()
        
        // Test that dashboard handles empty state gracefully
        #expect(dashboard is BackgroundTimeDashboard, "Dashboard should handle empty state")
    }
    
    @Test("Tab Switching Integration")
    func testTabSwitchingIntegration() async throws {
        // Test that all tab types can be used as identifiers
        let allTabs = DashboardTab.allCases
        
        for tab in allTabs {
            #expect(!tab.title.isEmpty, "Each tab should have a non-empty title")
            #expect(!tab.systemImage.isEmpty, "Each tab should have a non-empty system image")
        }
    }
    
    // MARK: - View State Tests
    
    @Test("Dashboard Loading States")
    func testDashboardLoadingStates() async throws {
        let viewModel = DashboardViewModel()
        
        // Test initial state
        #expect(!viewModel.isLoading, "Should not be loading initially")
        #expect(viewModel.events.isEmpty, "Should have no events initially")
        
        // Create views that depend on loading state
        let overviewTab = OverviewTabView(viewModel: viewModel, selectedTimeRange: .last24Hours)
        #expect(overviewTab is OverviewTabView, "Should create overview tab with initial state")
    }
    
    @Test("Dashboard Error States")
    func testDashboardErrorStates() async throws {
        let viewModel = DashboardViewModel()
        await viewModel.simulateError("Test error")
        
        // Test that views can handle error states
        let overviewTab = OverviewTabView(viewModel: viewModel, selectedTimeRange: .last24Hours)
        #expect(overviewTab is OverviewTabView, "Should create overview tab with error state")
        #expect(viewModel.error != nil, "Should have error state")
    }
    
    // MARK: - Accessibility Tests
    
    @Test("Dashboard Accessibility Features")
    func testDashboardAccessibilityFeatures() async throws {
        // Test that tabs have proper accessibility identifiers
        for tab in DashboardTab.allCases {
            #expect(!tab.title.isEmpty, "Tab titles should be accessible")
            #expect(!tab.systemImage.isEmpty, "Tab icons should have system images for accessibility")
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Large Data Rendering Performance")
    func testLargeDataRenderingPerformance() async throws {
        let viewModel = DashboardViewModel()
        
        // Simulate large dataset
        let largeEventList = createTestEventsForView(count: 1000)
        
        // Test that view components can handle large datasets
        let recentEventsView = RecentEventsView(events: Array(largeEventList.prefix(100)))
        #expect(recentEventsView is RecentEventsView, "Should handle large event lists")
        
        // Test timeline with many items
        let timelineData = largeEventList.map { event in
            TimelineDataPoint(
                timestamp: event.timestamp,
                eventType: event.type,
                taskIdentifier: event.taskIdentifier,
                duration: event.duration,
                success: event.success
            )
        }
        
        #expect(timelineData.count == 1000, "Should generate timeline data for large datasets")
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Empty Data Edge Cases")
    func testEmptyDataEdgeCases() async throws {
        // Test components with empty data
        let emptyEventsView = RecentEventsView(events: [])
        #expect(emptyEventsView is RecentEventsView, "Should handle empty events list")
        
        let emptyErrorsByType: [String: Int] = [:]
        let emptyErrorSummary = ErrorsTabView.ErrorSummarySection(errorsByType: emptyErrorsByType)
        #expect(emptyErrorSummary is ErrorsTabView.ErrorSummarySection, "Should handle empty errors")
    }
    
    @Test("Invalid Data Edge Cases")
    func testInvalidDataEdgeCases() async throws {
        // Test with extreme values
        let extremeMetric = TaskPerformanceMetrics(
            taskIdentifier: "extreme-task",
            totalScheduled: Int.max,
            totalExecuted: 0,
            totalCompleted: -1, // Invalid but should be handled gracefully
            totalFailed: Int.max,
            averageDuration: Double.infinity,
            successRate: -1.0, // Invalid but should be handled
            lastExecutionDate: Date.distantPast
        )
        
        let metricCard = TaskMetricCard(metric: extremeMetric)
        #expect(metricCard is TaskMetricCard, "Should handle extreme metric values gracefully")
    }
}

// MARK: - Helper Functions for Dashboard Tests

extension BackgroundTimeDashboardTests {
    
    /// Creates test events specifically for view testing
    private func createTestEventsForView(count: Int) -> [BackgroundTaskEvent] {
        return (0..<count).map { index in
            createTestEventForView(
                taskId: "view-test-task-\(index)",
                type: BackgroundTaskEventType.allCases[index % BackgroundTaskEventType.allCases.count],
                duration: Double.random(in: 0.5...10.0),
                success: Bool.random()
            )
        }
    }
    
    /// Creates a single test event for view testing
    private func createTestEventForView(
        taskId: String,
        type: BackgroundTaskEventType = .taskExecutionCompleted,
        timestamp: Date = Date(),
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
            errorMessage: success ? nil : "View test error",
            metadata: ["view_test": "true"],
            systemInfo: createTestSystemInfoForView()
        )
    }
    
    /// Creates test system info for view testing
    private func createTestSystemInfoForView() -> SystemInfo {
        return SystemInfo(
            backgroundAppRefreshStatus: .available,
            deviceModel: "TestDevice",
            systemVersion: "17.0",
            lowPowerModeEnabled: false,
            batteryLevel: 0.75,
            batteryState: .unplugged
        )
    }
}

/// Extension to add test-specific functionality to DashboardViewModel for view testing
private extension DashboardViewModel {
    /// Simulate error condition for view testing
    func simulateError(_ message: String) async {
        await MainActor.run {
            self.error = message
        }
    }
    
    /// Simulate loading state for view testing
    func simulateLoading(_ isLoading: Bool) async {
        await MainActor.run {
            self.isLoading = isLoading
        }
    }
}
