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
        let dataStore = BackgroundTaskDataStore.shared
        
        // Clear existing data
        dataStore.clearAllEvents()
        
        // Create test events with different timestamps
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let sixHoursAgo = now.addingTimeInterval(-6 * 3600)
        let oneDayAgo = now.addingTimeInterval(-24 * 3600)
        let oneWeekAgo = now.addingTimeInterval(-7 * 24 * 3600)
        
        let testEvents = [
            BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: "test-task-1",
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
                taskIdentifier: "test-task-2", 
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
                taskIdentifier: "test-task-3",
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
                taskIdentifier: "test-task-4",
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
        
        // Wait a moment for async operations
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Test 1 hour filtering
        let oneHourRange = TimeRange.last1Hour
        let startDate1h = now.addingTimeInterval(-oneHourRange.timeInterval)
        let events1h = dataStore.getEventsInDateRange(from: startDate1h, to: now)
        #expect(events1h.count == 1, "Should find 1 event in last hour")
        
        // Test 6 hours filtering
        let sixHoursRange = TimeRange.last6Hours
        let startDate6h = now.addingTimeInterval(-sixHoursRange.timeInterval)
        let events6h = dataStore.getEventsInDateRange(from: startDate6h, to: now)
        #expect(events6h.count == 2, "Should find 2 events in last 6 hours")
        
        // Test 24 hours filtering
        let twentyFourHoursRange = TimeRange.last24Hours
        let startDate24h = now.addingTimeInterval(-twentyFourHoursRange.timeInterval)
        let events24h = dataStore.getEventsInDateRange(from: startDate24h, to: now)
        #expect(events24h.count == 3, "Should find 3 events in last 24 hours")
        
        // Test 7 days filtering
        let sevenDaysRange = TimeRange.last7Days
        let startDate7d = now.addingTimeInterval(-sevenDaysRange.timeInterval)
        let events7d = dataStore.getEventsInDateRange(from: startDate7d, to: now)
        #expect(events7d.count == 4, "Should find 4 events in last 7 days")
        
        // Clean up
        dataStore.clearAllEvents()
    }
    
    @Test("Dashboard view model respects time range selection")
    func testViewModelTimeRangeFiltering() async throws {
        let viewModel = await DashboardViewModel()
        let dataStore = BackgroundTaskDataStore.shared
        
        // Clear existing data
        dataStore.clearAllEvents()
        
        // Create test events
        let now = Date()
        let systemInfo = SystemInfo(
            backgroundAppRefreshStatus: .available,
            deviceModel: "iPhone",
            systemVersion: "iOS 16.0",
            lowPowerModeEnabled: false,
            batteryLevel: 0.8,
            batteryState: .unplugged
        )
        
        let recentEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "recent-task",
            type: .taskExecutionCompleted,
            timestamp: now.addingTimeInterval(-30 * 60), // 30 minutes ago
            duration: 5.0,
            success: true,
            systemInfo: systemInfo
        )
        
        let oldEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "old-task",
            type: .taskExecutionCompleted,
            timestamp: now.addingTimeInterval(-2 * 24 * 3600), // 2 days ago
            duration: 3.0,
            success: true,
            systemInfo: systemInfo
        )
        
        // Add events
        dataStore.recordEvent(recentEvent)
        dataStore.recordEvent(oldEvent)
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Test 1 hour filter - should only show recent event
        await viewModel.loadData(for: .last1Hour)
        let events1h = await MainActor.run { viewModel.events }
        #expect(events1h.count == 1, "Should show 1 event for 1 hour range")
        #expect(events1h.first?.taskIdentifier == "recent-task", "Should show the recent task")
        
        // Test 7 days filter - should show both events
        await viewModel.loadData(for: .last7Days)
        let events7d = await MainActor.run { viewModel.events }
        #expect(events7d.count == 2, "Should show 2 events for 7 days range")
        
        // Verify statistics are filtered correctly
        let stats1h = await viewModel.statistics
        #expect(stats1h?.totalTasksExecuted == 1, "Statistics should reflect filtered data")
        
        // Clean up
        dataStore.clearAllEvents()
    }
}
