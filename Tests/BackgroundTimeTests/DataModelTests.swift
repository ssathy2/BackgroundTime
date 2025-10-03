//
//  DataModelTests.swift
//  BackgroundTimeTests
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Testing
import Foundation
import UIKit
import BackgroundTasks
@testable import BackgroundTime

@Suite("Data Model Tests")
struct DataModelTests {
    
    @Test("BackgroundTaskEvent Encoding and Decoding")
    func testBackgroundTaskEventCodable() async throws {
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "test-task",
            type: .taskScheduled,
            timestamp: Date(),
            duration: 5.0,
            success: true,
            errorMessage: nil,
            metadata: ["key": "value"],
            systemInfo: createMockSystemInfo()
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        
        let decoder = JSONDecoder()
        let decodedEvent = try decoder.decode(BackgroundTaskEvent.self, from: data)
        
        #expect(decodedEvent.id == event.id)
        #expect(decodedEvent.taskIdentifier == event.taskIdentifier)
        #expect(decodedEvent.type == event.type)
        #expect(decodedEvent.success == event.success)
        #expect(decodedEvent.duration == event.duration)
    }
    
    @Test("SystemInfo Encoding and Decoding")
    func testSystemInfoCodable() async throws {
        let systemInfo = createMockSystemInfo()
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(systemInfo)
        
        let decoder = JSONDecoder()
        let decodedSystemInfo = try decoder.decode(SystemInfo.self, from: data)
        
        #expect(decodedSystemInfo.deviceModel == systemInfo.deviceModel)
        #expect(decodedSystemInfo.systemVersion == systemInfo.systemVersion)
        #expect(decodedSystemInfo.lowPowerModeEnabled == systemInfo.lowPowerModeEnabled)
    }
    
    @Test("Statistics Generation with Empty Data")
    func testStatisticsWithEmptyData() async throws {
        // Use isolated test instance
        let dataStore = BackgroundTaskDataStore.createTestInstance()
        
        // Generate statistics with an empty array to test the statistics generation logic
        let emptyEvents: [BackgroundTaskEvent] = []
        let stats = dataStore.generateStatistics(for: emptyEvents, in: Date.distantPast...Date.distantFuture)
        
        #expect(stats.totalTasksScheduled == 0, "Should have 0 scheduled tasks with empty data")
        #expect(stats.totalTasksExecuted == 0, "Should have 0 executed tasks with empty data")
        #expect(stats.totalTasksCompleted == 0, "Should have 0 completed tasks with empty data")
        #expect(stats.totalTasksFailed == 0, "Should have 0 failed tasks with empty data")
        #expect(stats.successRate == 0.0, "Success rate should be 0.0 with empty data")
        #expect(stats.averageExecutionTime == 0.0, "Average execution time should be 0.0 with empty data")
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