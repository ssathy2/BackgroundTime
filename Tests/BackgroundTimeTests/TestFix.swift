//
//  TestFix.swift
//  BackgroundTimeTests
//
//  Created to verify the statistics behavior
//
//  CORRECTED UNDERSTANDING:
//  - totalTasksCompleted counts only successful completions (success=true)
//  - Failed completions are counted in totalTasksFailed, not totalTasksCompleted
//  - This is consistent with treating "completed" as "successfully completed"
//

import Testing
import Foundation
import UIKit
@testable import BackgroundTime

@Suite("Statistics Behavior Verification - Completed = Successful Only")
struct CompletionCountingFixTest {
    
    private func createTestEvent(taskId: String, type: BackgroundTaskEventType, success: Bool, duration: TimeInterval? = nil) -> BackgroundTaskEvent {
        return BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskId,
            type: type,
            timestamp: Date(),
            duration: duration,
            success: success,
            errorMessage: success ? nil : "Test error",
            metadata: [:],
            systemInfo: SystemInfo(
                backgroundAppRefreshStatus: .available,
                deviceModel: "TestDevice",
                systemVersion: "17.0",
                lowPowerModeEnabled: false,
                batteryLevel: 1.0,
                batteryState: .unplugged
            )
        )
    }
    
    @Test("Fix verification: Failed completion should count as failed, not completed")
    func testFailedCompletionCounting() async throws {
        let customDefaults = UserDefaults(suiteName: "TestFix.FailedCompletion") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "TestFix.FailedCompletion")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Record a task that starts and then completes unsuccessfully
        let startEvent = createTestEvent(taskId: "task-1", type: .taskExecutionStarted, success: true)
        let failedCompletionEvent = createTestEvent(taskId: "task-1", type: .taskExecutionCompleted, success: false, duration: 1.0)
        
        dataStore.recordEvent(startEvent)
        dataStore.recordEvent(failedCompletionEvent)
        
        let statistics = dataStore.generateStatistics()
        
        // Verify the behavior: failed completion counts as failed, not completed
        // In the current implementation, "completed" means "successfully completed"
        #expect(statistics.totalTasksExecuted == 1, "Should have 1 executed task")
        #expect(statistics.totalTasksCompleted == 0, "Should have 0 completed tasks (completion was unsuccessful)")
        #expect(statistics.totalTasksFailed == 1, "Should have 1 failed task (failed completion)")
        #expect(statistics.successRate == 0.0, "Success rate should be 0% since task failed")
    }
    
    @Test("Fix verification: Mixed success and failed completions")
    func testMixedCompletions() async throws {
        let customDefaults = UserDefaults(suiteName: "TestFix.MixedCompletions") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "TestFix.MixedCompletions")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Record 2 successful and 1 failed completion
        let events = [
            createTestEvent(taskId: "task-1", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-1", type: .taskExecutionCompleted, success: true, duration: 1.0),
            createTestEvent(taskId: "task-2", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-2", type: .taskExecutionCompleted, success: true, duration: 1.5),
            createTestEvent(taskId: "task-3", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-3", type: .taskExecutionCompleted, success: false, duration: 0.5)
        ]
        
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let statistics = dataStore.generateStatistics()
        
        // Verify the behavior: only successful completions count as "completed"
        #expect(statistics.totalTasksExecuted == 3, "Should have 3 executed tasks")
        #expect(statistics.totalTasksCompleted == 2, "Should have 2 completed tasks (only successful ones)")
        #expect(statistics.totalTasksFailed == 1, "Should have 1 failed task (the unsuccessful completion)")
        #expect(abs(statistics.successRate - 0.6667) < 0.001, "Success rate should be ~66.67% (2/3)")
    }
}
