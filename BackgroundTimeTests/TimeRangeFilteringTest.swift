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
        
        // Store existing events to restore later
        let existingEvents = dataStore.getAllEvents()
        
        // Clear existing data and wait for it to complete
        dataStore.clearAllEvents()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds - longer wait
        
        // Verify data store is actually cleared
        let eventsAfterClear = dataStore.getAllEvents()
        #expect(eventsAfterClear.count == 0, "Data store should be empty after clear, found \(eventsAfterClear.count) events")
        
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
        
        // Wait longer for async operations and persistence
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds - longer wait
        
        // Verify events were actually stored
        let allEventsAfterAdd = dataStore.getAllEvents()
        let testEventsInStore = allEventsAfterAdd.filter { $0.taskIdentifier.hasPrefix(testPrefix) }
        print("Debug: Total events in store after add: \(allEventsAfterAdd.count)")
        print("Debug: Test events in store: \(testEventsInStore.count)")
        print("Debug: Test event identifiers: \(testEventsInStore.map { $0.taskIdentifier })")
        print("Debug: Test event timestamps: \(testEventsInStore.map { $0.timestamp })")
        
        #expect(testEventsInStore.count == 4, "Should have 4 test events stored, found \(testEventsInStore.count)")
        
        // Helper function to filter only our test events
        func getTestEventsInDateRange(from startDate: Date, to endDate: Date) -> [BackgroundTaskEvent] {
            let allInRange = dataStore.getEventsInDateRange(from: startDate, to: endDate)
            let testInRange = allInRange.filter { $0.taskIdentifier.hasPrefix(testPrefix) }
            print("Debug: getEventsInDateRange from \(startDate) to \(endDate) returned \(allInRange.count) total events, \(testInRange.count) test events")
            return testInRange
        }
        
        // Test 1 hour filtering
        let oneHourRange = TimeRange.last1Hour
        let startDate1h = now.addingTimeInterval(-oneHourRange.timeInterval)
        print("Debug: Testing 1 hour range from \(startDate1h) to \(futureTime)")
        print("Debug: oneHourAgo timestamp: \(oneHourAgo), is in range: \(oneHourAgo >= startDate1h && oneHourAgo <= futureTime)")
        let events1h = getTestEventsInDateRange(from: startDate1h, to: futureTime)
        #expect(events1h.count == 1, "Should find 1 test event in last hour, found \(events1h.count)")
        
        // Test 6 hours filtering
        let sixHoursRange = TimeRange.last6Hours
        let startDate6h = now.addingTimeInterval(-sixHoursRange.timeInterval)
        print("Debug: Testing 6 hours range from \(startDate6h) to \(futureTime)")
        let events6h = getTestEventsInDateRange(from: startDate6h, to: futureTime)
        #expect(events6h.count == 2, "Should find 2 test events in last 6 hours, found \(events6h.count)")
        
        // Test 24 hours filtering
        let twentyFourHoursRange = TimeRange.last24Hours
        let startDate24h = now.addingTimeInterval(-twentyFourHoursRange.timeInterval)
        print("Debug: Testing 24 hours range from \(startDate24h) to \(futureTime)")
        let events24h = getTestEventsInDateRange(from: startDate24h, to: futureTime)
        #expect(events24h.count == 3, "Should find 3 test events in last 24 hours, found \(events24h.count)")
        
        // Test 7 days filtering
        let sevenDaysRange = TimeRange.last7Days
        let startDate7d = now.addingTimeInterval(-sevenDaysRange.timeInterval)
        print("Debug: Testing 7 days range from \(startDate7d) to \(futureTime)")
        let events7d = getTestEventsInDateRange(from: startDate7d, to: futureTime)
        #expect(events7d.count == 4, "Should find 4 test events in last 7 days, found \(events7d.count)")
        
        // Clean up by restoring original events
        dataStore.clearAllEvents()
        try await Task.sleep(nanoseconds: 200_000_000)
        for event in existingEvents {
            dataStore.recordEvent(event)
        }
    }
    
    @Test("Dashboard view model respects time range selection")
    func testViewModelTimeRangeFiltering() async throws {
        let viewModel = await DashboardViewModel()
        let dataStore = BackgroundTaskDataStore.shared
        
        // Create unique task identifiers for this test to avoid contamination
        let testPrefix = "viewmodel_test_\(UUID().uuidString.prefix(8))_"
        
        // Store existing events to restore later
        let existingEvents = dataStore.getAllEvents()
        
        // Clear existing data thoroughly and wait longer
        dataStore.clearAllEvents()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds - longer wait
        
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
        
        // Wait longer for async operations and persistence
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds - longer wait
        
        // Helper function to get only our test events
        func getTestEvents(from events: [BackgroundTaskEvent]) -> [BackgroundTaskEvent] {
            return events.filter { $0.taskIdentifier.hasPrefix(testPrefix) }
        }
        
        // Verify we have our test events in the data store first
        let allEventsAfterAdd = dataStore.getAllEvents()
        let testEventsAfterAdd = getTestEvents(from: allEventsAfterAdd)
        #expect(testEventsAfterAdd.count == 4, "Should have exactly 4 test events (2 start + 2 complete), found \(testEventsAfterAdd.count). All events count: \(allEventsAfterAdd.count)")
        
        // Force the view model to load data for 1 hour with explicit timing
        await MainActor.run {
            viewModel.isLoading = false // Reset loading state to ensure loadData doesn't return early
        }
        
        await viewModel.loadData(for: .last1Hour)
        
        // Wait longer for the view model to process completely and check loading state
        var retryCount = 0
        while retryCount < 20 { // Maximum 2 seconds
            let isLoading = await MainActor.run { viewModel.isLoading }
            if !isLoading {
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            retryCount += 1
        }
        
        // Additional wait to ensure all operations complete
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        let events1h = await MainActor.run { getTestEvents(from: viewModel.events) }
        let allViewModelEvents1h = await MainActor.run { viewModel.events }
        print("Debug: events1h count = \(events1h.count), viewModel.events count = \(allViewModelEvents1h.count)")
        print("Debug: events1h identifiers = \(events1h.map { $0.taskIdentifier })")
        print("Debug: All viewModel event identifiers = \(allViewModelEvents1h.map { $0.taskIdentifier })")
        #expect(events1h.count == 2, "Should show 2 test events (1 start + 1 complete) for 1 hour range, found \(events1h.count)")
        #expect(events1h.contains { $0.taskIdentifier == "\(testPrefix)recent-task" }, "Should show the recent task events")
        
        // Force the view model to load data for 7 days - ensure it's different from the previous call
        await MainActor.run {
            viewModel.isLoading = false // Reset loading state to ensure loadData doesn't return early
        }
        
        await viewModel.loadData(for: .last7Days)
        
        // Wait longer for the view model to process completely and check loading state
        retryCount = 0
        while retryCount < 20 { // Maximum 2 seconds
            let isLoading = await MainActor.run { viewModel.isLoading }
            if !isLoading {
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            retryCount += 1
        }
        
        // Additional wait to ensure all operations complete
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        let events7d = await MainActor.run { getTestEvents(from: viewModel.events) }
        let allViewModelEvents7d = await MainActor.run { viewModel.events }
        print("Debug: events7d count = \(events7d.count), viewModel.events count = \(allViewModelEvents7d.count)")
        print("Debug: events7d identifiers = \(events7d.map { $0.taskIdentifier })")
        print("Debug: All viewModel event identifiers 7d = \(allViewModelEvents7d.map { $0.taskIdentifier })")
        #expect(events7d.count == 4, "Should show 4 test events (2 start + 2 complete) for 7 days range, found \(events7d.count)")
        
        // Verify statistics include at least our test events
        let stats = await MainActor.run { viewModel.statistics }
        print("Debug: Statistics - totalTasksExecuted = \(stats?.totalTasksExecuted ?? 0)")
        #expect((stats?.totalTasksExecuted ?? 0) >= 2, "Statistics should reflect filtered data with at least 2 tasks executed, found \(stats?.totalTasksExecuted ?? 0)")
        
        // Clean up by restoring original events
        dataStore.clearAllEvents()
        try await Task.sleep(nanoseconds: 200_000_000)
        for event in existingEvents {
            dataStore.recordEvent(event)
        }
    }
}
