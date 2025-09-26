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
        
        // Clear existing data and wait for it to complete
        dataStore.clearAllEvents()
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Create unique task identifiers for this test to avoid contamination
        let testPrefix = "timerange_test_\(UUID().uuidString.prefix(8))_"
        
        // Create test events with different timestamps
        let now = Date()
        let futureTime = now.addingTimeInterval(60) // 1 minute in the future for range end
        let oneHourAgo = now.addingTimeInterval(-3600)
        let sixHoursAgo = now.addingTimeInterval(-6 * 3600)
        let oneDayAgo = now.addingTimeInterval(-24 * 3600)
        let oneWeekAgo = now.addingTimeInterval(-7 * 24 * 3600)
        
        let testEvents = [
            BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: "\(testPrefix)task-1",
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
                taskIdentifier: "\(testPrefix)task-2",
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
                taskIdentifier: "\(testPrefix)task-3",
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
                taskIdentifier: "\(testPrefix)task-4",
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
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Helper function to filter only our test events
        func getTestEventsInDateRange(from startDate: Date, to endDate: Date) -> [BackgroundTaskEvent] {
            return dataStore.getEventsInDateRange(from: startDate, to: endDate)
                .filter { $0.taskIdentifier.hasPrefix(testPrefix) }
        }
        
        // Test 1 hour filtering
        let oneHourRange = TimeRange.last1Hour
        let startDate1h = now.addingTimeInterval(-oneHourRange.timeInterval)
        let events1h = getTestEventsInDateRange(from: startDate1h, to: futureTime)
        #expect(events1h.count == 1, "Should find 1 test event in last hour, found \(events1h.count)")
        
        // Test 6 hours filtering
        let sixHoursRange = TimeRange.last6Hours
        let startDate6h = now.addingTimeInterval(-sixHoursRange.timeInterval)
        let events6h = getTestEventsInDateRange(from: startDate6h, to: futureTime)
        #expect(events6h.count == 2, "Should find 2 test events in last 6 hours, found \(events6h.count)")
        
        // Test 24 hours filtering
        let twentyFourHoursRange = TimeRange.last24Hours
        let startDate24h = now.addingTimeInterval(-twentyFourHoursRange.timeInterval)
        let events24h = getTestEventsInDateRange(from: startDate24h, to: futureTime)
        #expect(events24h.count == 3, "Should find 3 test events in last 24 hours, found \(events24h.count)")
        
        // Test 7 days filtering
        let sevenDaysRange = TimeRange.last7Days
        let startDate7d = now.addingTimeInterval(-sevenDaysRange.timeInterval)
        let events7d = getTestEventsInDateRange(from: startDate7d, to: futureTime)
        #expect(events7d.count == 4, "Should find 4 test events in last 7 days, found \(events7d.count)")
        
        // Clean up our test events by filtering them out from all events
        let allEvents = dataStore.getAllEvents()
        let nonTestEvents = allEvents.filter { !$0.taskIdentifier.hasPrefix(testPrefix) }
        
        // Clear and re-add non-test events
        dataStore.clearAllEvents()
        for event in nonTestEvents {
            dataStore.recordEvent(event)
        }
    }
    
    @Test("Dashboard view model respects time range selection")
    func testViewModelTimeRangeFiltering() async throws {
        let viewModel = await DashboardViewModel()
        let dataStore = BackgroundTaskDataStore.shared
        
        // Create unique task identifiers for this test to avoid contamination
        let testPrefix = "viewmodel_test_\(UUID().uuidString.prefix(8))_"
        
        // Clear existing data thoroughly and wait longer
        dataStore.clearAllEvents()
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Create test events with unique identifiers
        let now = Date()
        let systemInfo = SystemInfo(
            backgroundAppRefreshStatus: .available,
            deviceModel: "iPhone",
            systemVersion: "iOS 16.0",
            lowPowerModeEnabled: false,
            batteryLevel: 0.8,
            batteryState: .unplugged
        )
        
        // Create both execution started and completed events for proper statistics
        let recentStartEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "\(testPrefix)recent-task",
            type: .taskExecutionStarted,
            timestamp: now.addingTimeInterval(-30 * 60), // 30 minutes ago
            success: true,
            systemInfo: systemInfo
        )
        
        let recentCompleteEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "\(testPrefix)recent-task",
            type: .taskExecutionCompleted,
            timestamp: now.addingTimeInterval(-30 * 60 + 5), // 5 seconds later
            duration: 5.0,
            success: true,
            systemInfo: systemInfo
        )
        
        let oldStartEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "\(testPrefix)old-task",
            type: .taskExecutionStarted,
            timestamp: now.addingTimeInterval(-2 * 24 * 3600), // 2 days ago
            success: true,
            systemInfo: systemInfo
        )
        
        let oldCompleteEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "\(testPrefix)old-task",
            type: .taskExecutionCompleted,
            timestamp: now.addingTimeInterval(-2 * 24 * 3600 + 3), // 3 seconds later
            duration: 3.0,
            success: true,
            systemInfo: systemInfo
        )
        
        // Add events (both start and complete events for proper statistics)
        dataStore.recordEvent(recentStartEvent)
        dataStore.recordEvent(recentCompleteEvent)
        dataStore.recordEvent(oldStartEvent)
        dataStore.recordEvent(oldCompleteEvent)
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Helper function to get only our test events
        func getTestEvents(from events: [BackgroundTaskEvent]) -> [BackgroundTaskEvent] {
            return events.filter { $0.taskIdentifier.hasPrefix(testPrefix) }
        }
        
        // Verify we have only our test events in the data store (4 events: 2 start + 2 complete)
        let allEvents = dataStore.getAllEvents()
        let testEvents = getTestEvents(from: allEvents)
        #expect(testEvents.count == 4, "Should have exactly 4 test events (2 start + 2 complete), found \(testEvents.count)")
        
        // Test 1 hour filter - should only show recent event
        await viewModel.loadData(for: .last1Hour)
        
        // Wait for the view model to process
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let events1h = await MainActor.run { getTestEvents(from: viewModel.events) }
        #expect(events1h.count == 2, "Should show 2 test events (1 start + 1 complete) for 1 hour range, found \(events1h.count)")
        #expect(events1h.contains { $0.taskIdentifier == "\(testPrefix)recent-task" }, "Should show the recent task events")
        
        // Test 7 days filter - should show both events  
        await viewModel.loadData(for: .last7Days)
        
        // Wait for the view model to process
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let events7d = await MainActor.run { getTestEvents(from: viewModel.events) }
        #expect(events7d.count == 4, "Should show 4 test events (2 start + 2 complete) for 7 days range, found \(events7d.count)")
        
        // Verify statistics include at least our test events
        let stats = await MainActor.run { viewModel.statistics }
        #expect((stats?.totalTasksExecuted ?? 0) >= 1, "Statistics should reflect filtered data")
        
        // Clean up our test events by filtering them out from all events
        let finalAllEvents = dataStore.getAllEvents()
        let nonTestEvents = finalAllEvents.filter { !$0.taskIdentifier.hasPrefix(testPrefix) }
        
        // Clear and re-add non-test events
        dataStore.clearAllEvents()
        for event in nonTestEvents {
            dataStore.recordEvent(event)
        }
    }
}
