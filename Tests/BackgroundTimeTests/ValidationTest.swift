import Testing
import Foundation
import UIKit
@testable import BackgroundTime

@Suite("Statistics Logic Validation - Corrected Expectations")
struct LogicValidationTest {
    
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
    
    @Test("Validation: Statistics invariants hold")
    func testStatisticsInvariants() async throws {
        let customDefaults = UserDefaults(suiteName: "ValidationTest") ?? UserDefaults.standard
        customDefaults.removePersistentDomain(forName: "ValidationTest")
        let dataStore = BackgroundTaskDataStore(userDefaults: customDefaults)
        
        // Create a mix of different scenarios:
        // 1. Task that completes successfully
        // 2. Task that completes but fails
        // 3. Task that expires (doesn't complete)
        // 4. Task that gets cancelled (doesn't complete)
        // 5. Task that explicitly fails (doesn't complete)
        
        let events = [
            // Task 1: Successful completion
            createTestEvent(taskId: "task-1", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-1", type: .taskExecutionCompleted, success: true, duration: 1.0),
            
            // Task 2: Failed completion
            createTestEvent(taskId: "task-2", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-2", type: .taskExecutionCompleted, success: false, duration: 0.5),
            
            // Task 3: Expired (no completion)
            createTestEvent(taskId: "task-3", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-3", type: .taskExpired, success: false),
            
            // Task 4: Cancelled (no completion)
            createTestEvent(taskId: "task-4", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-4", type: .taskCancelled, success: false),
            
            // Task 5: Explicit failure (no completion)
            createTestEvent(taskId: "task-5", type: .taskExecutionStarted, success: true),
            createTestEvent(taskId: "task-5", type: .taskFailed, success: false)
        ]
        
        for event in events {
            dataStore.recordEvent(event)
        }
        
        let statistics = dataStore.generateStatistics()
        
        // Validate basic invariants
        #expect(statistics.totalTasksExecuted == 5, "Should have 5 executed tasks")
        #expect(statistics.totalTasksCompleted == 1, "Should have 1 completed task (only successful completion)")
        #expect(statistics.totalTasksFailed == 4, "Should have 4 failed tasks (1 failed completion + 1 expired + 1 cancelled + 1 explicit failure)")
        
        // Critical invariants that were failing before
        #expect(statistics.totalTasksFailed <= statistics.totalTasksExecuted + 1, 
                "Failed tasks (\(statistics.totalTasksFailed)) should be close to executed tasks (\(statistics.totalTasksExecuted))")
        #expect(statistics.totalTasksCompleted <= statistics.totalTasksExecuted,
                "Completed tasks (\(statistics.totalTasksCompleted)) should be <= executed tasks (\(statistics.totalTasksExecuted))")
        
        // Success rate should be based on successful completions vs total executed
        #expect(statistics.successRate == 0.2, "Success rate should be 20% (1 success out of 5 executed)")
    }
}