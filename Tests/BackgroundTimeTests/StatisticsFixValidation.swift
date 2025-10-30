//
//  StatisticsFixValidation.swift
//  BackgroundTimeTests
//
//  Created by Assistant on 10/15/25.
//

import Testing
import Foundation
import UIKit
@testable import BackgroundTime

@Suite("Statistics Fix Validation")
struct StatisticsFixValidation {
    
    @Test("Fixed statistics calculation maintains mathematical consistency")
    func testFixedStatisticsConsistency() async throws {
        let customDefaults = UserDefaults(suiteName: "StatisticsFixValidation") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "StatisticsFixValidation")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create test events: 2 successful, 1 failed completion, 1 expired
        let events = [
            // Task 1: successful
            BackgroundTaskEvent(id: UUID(), taskIdentifier: "task1", type: .taskExecutionStarted, timestamp: Date(), success: true, systemInfo: createTestSystemInfo()),
            BackgroundTaskEvent(id: UUID(), taskIdentifier: "task1", type: .taskExecutionCompleted, timestamp: Date().addingTimeInterval(5), duration: 5.0, success: true, systemInfo: createTestSystemInfo()),
            
            // Task 2: successful
            BackgroundTaskEvent(id: UUID(), taskIdentifier: "task2", type: .taskExecutionStarted, timestamp: Date().addingTimeInterval(10), success: true, systemInfo: createTestSystemInfo()),
            BackgroundTaskEvent(id: UUID(), taskIdentifier: "task2", type: .taskExecutionCompleted, timestamp: Date().addingTimeInterval(18), duration: 8.0, success: true, systemInfo: createTestSystemInfo()),
            
            // Task 3: failed completion
            BackgroundTaskEvent(id: UUID(), taskIdentifier: "task3", type: .taskExecutionStarted, timestamp: Date().addingTimeInterval(20), success: true, systemInfo: createTestSystemInfo()),
            BackgroundTaskEvent(id: UUID(), taskIdentifier: "task3", type: .taskExecutionCompleted, timestamp: Date().addingTimeInterval(25), duration: 5.0, success: false, systemInfo: createTestSystemInfo()),
            
            // Task 4: expired (no completion event)
            BackgroundTaskEvent(id: UUID(), taskIdentifier: "task4", type: .taskExecutionStarted, timestamp: Date().addingTimeInterval(30), success: true, systemInfo: createTestSystemInfo()),
            BackgroundTaskEvent(id: UUID(), taskIdentifier: "task4", type: .taskExpired, timestamp: Date().addingTimeInterval(60), success: true, systemInfo: createTestSystemInfo())
        ]
        
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let statistics = dataStore.generateStatistics()
        
        // Verify mathematical consistency
        #expect(statistics.totalTasksExecuted == 4, "Should have 4 executed tasks")
        #expect(statistics.totalTasksCompleted == 2, "Should have 2 successfully completed tasks (not 3)")
        #expect(statistics.totalTasksFailed == 2, "Should have 2 failed tasks (1 failed completion + 1 expired)")
        #expect(statistics.totalTasksExpired == 1, "Should have 1 expired task")
        
        // Mathematical consistency checks
        #expect(statistics.totalTasksCompleted <= statistics.totalTasksExecuted, 
                "Completed should be <= executed")
        #expect(statistics.totalTasksFailed <= statistics.totalTasksExecuted,
                "Failed should be <= executed")
        #expect(statistics.totalTasksCompleted + statistics.totalTasksFailed <= statistics.totalTasksExecuted,
                "Completed + Failed should be <= executed")
        
        // Success rate should be 2/4 = 0.5 (50%)
        #expect(abs(statistics.successRate - 0.5) < 0.001, "Success rate should be 50% (0.5)")
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
