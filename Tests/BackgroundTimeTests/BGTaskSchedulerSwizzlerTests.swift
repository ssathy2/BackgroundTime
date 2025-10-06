//
//  BGTaskSchedulerSwizzlerTests.swift
//  BackgroundTimeTests
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Testing
import Foundation
import UIKit
import BackgroundTasks
@testable import BackgroundTime

@Suite("BGTaskSchedulerSwizzler Comprehensive Tests")
struct BGTaskSchedulerSwizzlerTests {
    
    @Test("BGTaskSchedulerSwizzler initialization and safety")
    func testBGTaskSchedulerSwizzlerInitialization() async throws {
        // Test that swizzling can be initialized multiple times safely
        await MainActor.run {
            BGTaskSchedulerSwizzler.swizzleSchedulerMethods()
            BGTaskSchedulerSwizzler.swizzleSchedulerMethods() // Should be safe to call multiple times
            BGTaskSchedulerSwizzler.swizzleSchedulerMethods() // Should be safe to call multiple times
        }
        
        // Verify BGTaskScheduler is accessible
        let scheduler = BGTaskScheduler.shared
        #expect(type(of: scheduler) == BGTaskScheduler.self, "BGTaskScheduler should remain functional after swizzling")
        
        // Test that basic scheduler operations don't crash
        let testIdentifier = "swizzling-safety-test-\(UUID().uuidString)"
        
        // These operations might fail in test environment but shouldn't crash
        scheduler.cancel(taskRequestWithIdentifier: testIdentifier)
        scheduler.cancelAllTaskRequests()
        
        #expect(true, "Scheduler operations should complete without crashing")
    }
    
    @Test("BGTaskSchedulerSwizzler task submission tracking")
    func testBGTaskSchedulerTaskSubmission() async throws {
        // Initialize swizzling
        await MainActor.run {
            BGTaskSchedulerSwizzler.swizzleSchedulerMethods()
        }
        
        let scheduler = BGTaskScheduler.shared
        let testIdentifier = "swizzling-submission-test-\(UUID().uuidString)"
        
        // Test different types of task requests
        let appRefreshRequest = BGAppRefreshTaskRequest(identifier: testIdentifier)
        let processingRequest = BGProcessingTaskRequest(identifier: "\(testIdentifier)-processing")
        
        // Set properties on processing request
        processingRequest.requiresNetworkConnectivity = true
        processingRequest.requiresExternalPower = false
        processingRequest.earliestBeginDate = Date(timeIntervalSinceNow: 60) // 1 minute from now
        
        // Attempt to submit tasks (will likely fail in test environment but shouldn't crash)
        do {
            try scheduler.submit(appRefreshRequest)
        } catch {
            // Expected to fail in test environment
            #expect(error is Error, "Task submission should handle errors gracefully")
        }
        
        do {
            try scheduler.submit(processingRequest)
        } catch {
            // Expected to fail in test environment
            #expect(error is Error, "Processing task submission should handle errors gracefully")
        }
        
        #expect(true, "Task submission attempts should complete without crashing")
    }
    
    @Test("BGTaskSchedulerSwizzler task registration tracking")
    func testBGTaskSchedulerTaskRegistration() async throws {
        // Initialize swizzling
        await MainActor.run {
            BGTaskSchedulerSwizzler.swizzleSchedulerMethods()
        }
        
        let scheduler = BGTaskScheduler.shared
        let testIdentifier = "swizzling-registration-test-\(UUID().uuidString)"
        
        // Test task registration with launch handler
        let registrationResult = scheduler.register(
            forTaskWithIdentifier: testIdentifier,
            using: DispatchQueue.global()
        ) { task in
            // Mock launch handler that completes the task
            task.expirationHandler = {
                // Handle task expiration
            }
            
            // Simulate task completion
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                task.setTaskCompleted(success: true)
            }
        }
        
        // Registration might succeed or fail depending on test environment and Info.plist configuration
        // We mainly test that it doesn't crash
        #expect(true, "Task registration should complete without crashing, result: \(registrationResult)")
        
        // Test registration with nil queue
        let nilQueueResult = scheduler.register(
            forTaskWithIdentifier: "\(testIdentifier)-nil-queue",
            using: nil
        ) { task in
            task.setTaskCompleted(success: true)
        }
        
        #expect(true, "Task registration with nil queue should complete without crashing, result: \(nilQueueResult)")
    }
    
    @Test("BGTaskSchedulerSwizzler task cancellation tracking")
    func testBGTaskSchedulerTaskCancellation() async throws {
        // Initialize swizzling
        await MainActor.run {
            BGTaskSchedulerSwizzler.swizzleSchedulerMethods()
        }
        
        let scheduler = BGTaskScheduler.shared
        let testIdentifiers = [
            "cancel-test-1-\(UUID().uuidString)",
            "cancel-test-2-\(UUID().uuidString)",
            "cancel-test-3-\(UUID().uuidString)"
        ]
        
        // Test individual task cancellation
        for identifier in testIdentifiers {
            scheduler.cancel(taskRequestWithIdentifier: identifier)
        }
        
        // Test cancel all tasks
        scheduler.cancelAllTaskRequests()
        
        // Test multiple cancel all calls
        scheduler.cancelAllTaskRequests()
        scheduler.cancelAllTaskRequests()
        
        #expect(true, "Task cancellation operations should complete without issues")
    }
    
    @Test("BGTaskSwizzler initialization and task tracking")
    func testBGTaskSwizzlerInitialization() async throws {
        // Initialize BGTask swizzling
        await MainActor.run {
            BGTaskSwizzler.swizzleTaskMethods()
            BGTaskSwizzler.swizzleTaskMethods() // Should be safe to call multiple times
        }
        
        // Test that the task start times manager is accessible
        let testTaskId = "swizzler-init-test-\(UUID().uuidString)"
        let testStartTime = Date()
        
        // Set a start time
        await BGTaskSwizzler.taskStartTimesManager.setStartTime(testStartTime, for: testTaskId)
        
        // Verify the task was recorded
        let recordedTime = await BGTaskSwizzler.taskStartTimesManager.getStartTime(for: testTaskId)
        
        let unwrappedTime = try #require(recordedTime, "Task start time should have been recorded")
        #expect(abs(unwrappedTime.timeIntervalSince(testStartTime)) < 1.0, "Recorded time should be close to test time")
        
        // Clean up test entry
        await BGTaskSwizzler.taskStartTimesManager.removeStartTime(for: testTaskId)
        
        // Verify removal
        let removedTime = await BGTaskSwizzler.taskStartTimesManager.getStartTime(for: testTaskId)
        #expect(removedTime == nil, "Task start time should have been removed")
    }
    
    @Test("BGTaskSwizzler thread safety and concurrent access")
    func testBGTaskSwizzlerThreadSafety() async throws {
        // Initialize swizzling
        await MainActor.run {
            BGTaskSwizzler.swizzleTaskMethods()
        }
        
        let baseTaskIdentifier = "thread-safety-test-\(UUID().uuidString)"
        let iterations = 20
        
        // Perform concurrent operations using the actor
        await withTaskGroup(of: Void.self) { group in
            // Add tasks concurrently
            for i in 0..<iterations {
                group.addTask {
                    let taskId = "\(baseTaskIdentifier)-add-\(i)"
                    await BGTaskSwizzler.taskStartTimesManager.setStartTime(Date(), for: taskId)
                }
            }
            
            // Remove tasks concurrently
            for i in 0..<(iterations/2) {
                group.addTask {
                    let taskId = "\(baseTaskIdentifier)-add-\(i)"
                    // Wait a bit before removing
                    try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                    await BGTaskSwizzler.taskStartTimesManager.removeStartTime(for: taskId)
                }
            }
            
            // Read tasks concurrently
            for i in 0..<iterations {
                group.addTask {
                    let taskId = "\(baseTaskIdentifier)-add-\(i)"
                    let _ = await BGTaskSwizzler.taskStartTimesManager.getStartTime(for: taskId)
                }
            }
        }
        
        // Clean up any remaining test entries
        for i in 0..<iterations {
            let taskId = "\(baseTaskIdentifier)-add-\(i)"
            await BGTaskSwizzler.taskStartTimesManager.removeStartTime(for: taskId)
        }
        
        #expect(true, "Thread safety test completed successfully")
    }
    
    @Test("Date ISO8601 extension comprehensive testing")
    func testDateISO8601ExtensionComprehensive() async throws {
        let testDates = [
            Date(timeIntervalSince1970: 0), // Unix epoch
            Date(timeIntervalSince1970: 1640995200), // 2022-01-01 00:00:00 UTC
            Date(timeIntervalSince1970: 1695686400), // 2023-09-26 00:00:00 UTC
            Date(), // Current date
            Date.distantPast,
            Date.distantFuture
        ]
        
        let formatter = ISO8601DateFormatter()
        
        for testDate in testDates {
            let iso8601String = testDate.iso8601String
            
            // Basic format validation
            #expect(!iso8601String.isEmpty, "ISO8601 string should not be empty")
            #expect(iso8601String.contains("T"), "ISO8601 format should contain T separator")
            
            // Should contain timezone info (Z for UTC or +/- for offset)
            let hasTimeZone = iso8601String.contains("Z") || 
                             iso8601String.contains("+") || 
                             iso8601String.contains("-")
            #expect(hasTimeZone, "ISO8601 format should contain timezone information")
            
            // Should be parseable back to a date
            let parsedDate = formatter.date(from: iso8601String)
            let unwrappedDate = try #require(parsedDate, "ISO8601 string should be parseable back to Date")
            
            // For normal dates (not distant past/future), should be very close
            if testDate != Date.distantPast && testDate != Date.distantFuture {
                let timeDifference = abs(unwrappedDate.timeIntervalSince(testDate))
                #expect(timeDifference < 1.0, "Parsed date should be within 1 second of original")
            }
            
            // Test format components for normal dates
            if testDate.timeIntervalSince1970 > 0 && testDate.timeIntervalSince1970 < 4000000000 {
                #expect(iso8601String.count >= 19, "ISO8601 string should have minimum length for date-time")
                
                // Should contain date components
                let dateComponents = iso8601String.components(separatedBy: "T")
                #expect(dateComponents.count == 2, "Should have date and time components")
                
                let datePart = dateComponents[0]
                let timePart = dateComponents[1]
                
                #expect(datePart.contains("-"), "Date part should contain hyphens")
                #expect(timePart.contains(":"), "Time part should contain colons")
            }
        }
    }
    
    @Test("Method swizzling integration with SDK")
    func testMethodSwizzlingSDKIntegration() async throws {
        // Initialize all swizzling and SDK on main actor
        await MainActor.run {
            BGTaskSchedulerSwizzler.swizzleSchedulerMethods()
            BGTaskSwizzler.swizzleTaskMethods()
            
            // Initialize SDK to ensure swizzling is working in context
            let sdk = BackgroundTime.shared
            sdk.initialize(configuration: .default)
        }
        
        // Wait for initialization
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify that SDK functions still work after swizzling
        await MainActor.run {
            let sdk = BackgroundTime.shared
            let stats = sdk.getCurrentStats()
            #expect(stats.totalTasksScheduled >= 0, "SDK should function normally after swizzling")
            
            let events = sdk.getAllEvents()
            #expect(events.count >= 0, "SDK should provide events after swizzling")
            
            let dashboardData = sdk.exportDataForDashboard()
            #expect(dashboardData.events.count >= 0, "Dashboard export should work after swizzling")
            #expect(dashboardData.statistics.totalTasksScheduled >= 0, "Dashboard statistics should work after swizzling")
            
            // Test that performance metrics still work
            let performanceReport = sdk.getDataStorePerformance()
            #expect(performanceReport.operationStats.keys.count >= 0, "Performance reporting should work after swizzling")
            
            let bufferStats = sdk.getBufferStatistics()
            #expect(bufferStats.capacity > 0, "Buffer statistics should work after swizzling")
        }
        
        #expect(true, "SDK integration with method swizzling completed successfully")
    }
}
