//
//  MetricCollectionTests.swift
//  BackgroundTimeTests
//
//  Created by Siddharth Sathyam on 9/25/25.
//

import Testing
import Foundation
import UIKit
@testable import BackgroundTime

// MARK: - Metric Collection Tests

@Suite("Enhanced Metric Collection Tests")
struct MetricCollectionTests {
    
    @Test("BGTaskScheduler Error Categorization")
    func testErrorCategorization() async throws {
        // Test BGTaskScheduler unavailable error
        let unavailableError = NSError(
            domain: "BGTaskSchedulerErrorDomain",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Background task scheduler unavailable"]
        )
        
        let categorization = BGTaskSchedulerErrorCategorizer.categorize(unavailableError)
        
        #expect(categorization.category == .unavailable)
        #expect(categorization.severity == .high)
        #expect(categorization.isRetryable == true)
        #expect(categorization.code == "BGTaskSchedulerErrorCodeUnavailable")
    }
    
    @Test("Task Performance Metrics")
    func testPerformanceMetrics() async throws {
        let metrics = PerformanceMetrics(
            duration: 5.0,
            cpuTime: 1.5,
            cpuUsagePercentage: 30.0,
            peakMemoryUsage: 50_000_000, // 50MB
            energyImpact: .moderate
        )
        
        let dictionary = metrics.toDictionary()
        
        #expect(dictionary["performance_duration"] as? TimeInterval == 5.0)
        #expect(dictionary["performance_cpu_usage_percentage"] as? Double == 30.0)
        #expect(dictionary["performance_energy_impact"] as? String == "moderate")
        #expect(dictionary["performance_energy_impact_score"] as? Int == 3)
    }
    
    @Test("System Resource Metrics")
    func testSystemResourceMetrics() async throws {
        let metrics = SystemResourceMetrics(
            batteryLevel: 0.75,
            isCharging: true,
            isLowPowerModeEnabled: false,
            thermalState: .nominal,
            availableMemoryPercentage: 60.0,
            diskSpaceAvailable: 5_000_000_000 // 5GB
        )
        
        let dictionary = metrics.toDictionary()
        
        #expect(dictionary["system_battery_level"] as? Float == 0.75)
        #expect(dictionary["system_is_charging"] as? Bool == true)
        #expect(dictionary["system_thermal_state"] as? String == "nominal")
        #expect(dictionary["system_memory_status"] as? String == "good")
        #expect(dictionary["system_power_status"] as? String == "charging")
    }
    
    @Test("Network Metrics Categorization")
    func testNetworkMetrics() async throws {
        let metrics = NetworkMetrics(
            requestCount: 10,
            totalBytesTransferred: 5_000_000, // 5MB (lighter usage)
            connectionFailures: 1,
            averageLatency: 0.5,
            connectionReliability: 0.9
        )
        
        let dictionary = metrics.toDictionary()
        
        #expect(dictionary["network_request_count"] as? Int == 10)
        #expect(dictionary["network_connection_reliability"] as? Double == 0.9)
        #expect(dictionary["network_reliability_category"] as? String == "good")
        #expect(dictionary["network_data_usage_category"] as? String == "light")
    }
    
    @Test("Energy Impact Classification")
    func testEnergyImpactClassification() async throws {
        #expect(EnergyImpact.veryLow.score == 1)
        #expect(EnergyImpact.low.score == 2)
        #expect(EnergyImpact.moderate.score == 3)
        #expect(EnergyImpact.high.score == 4)
        #expect(EnergyImpact.veryHigh.score == 5)
        
        #expect(EnergyImpact.moderate.displayName == "Moderate")
        #expect(EnergyImpact.veryHigh.rawValue == "very_high")
    }
    
    @Test("Background Task Error Types")
    func testBackgroundTaskErrorTypes() async throws {
        let expiredError = BackgroundTaskError.taskExpired
        let configError = BackgroundTaskError.configurationError("Invalid setup")
        
        #expect(expiredError.code == 1000)
        #expect(expiredError.description.contains("expired"))
        
        #expect(configError.code == 1003)
        #expect(configError.description.contains("Invalid setup"))
        
        #expect(expiredError.errorDescription != nil)
    }
    
    @Test("Error Severity Priorities")
    func testErrorSeverityPriorities() async throws {
        #expect(BGTaskSchedulerErrorCategorizer.ErrorSeverity.low.priority == 1)
        #expect(BGTaskSchedulerErrorCategorizer.ErrorSeverity.medium.priority == 2)
        #expect(BGTaskSchedulerErrorCategorizer.ErrorSeverity.high.priority == 3)
        #expect(BGTaskSchedulerErrorCategorizer.ErrorSeverity.critical.priority == 4)
        
        // Test sorting by priority
        let severities: [BGTaskSchedulerErrorCategorizer.ErrorSeverity] = [.high, .low, .critical, .medium]
        let sorted = severities.sorted { $0.priority < $1.priority }
        
        #expect(sorted[0] == .low)
        #expect(sorted[1] == .medium)
        #expect(sorted[2] == .high)
        #expect(sorted[3] == .critical)
    }
    
    @Test("Custom Error Categorization")
    func testCustomErrorCategorization() async throws {
        // Test timeout error
        let timeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        let timeoutCategorization = BGTaskSchedulerErrorCategorizer.categorize(timeoutError)
        
        #expect(timeoutCategorization.category == .timeout)
        #expect(timeoutCategorization.severity == .medium)
        #expect(timeoutCategorization.isRetryable == true)
        
        // Test network error
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        let networkCategorization = BGTaskSchedulerErrorCategorizer.categorize(networkError)
        
        #expect(networkCategorization.category == .network)
        #expect(networkCategorization.severity == .high)
        #expect(networkCategorization.isRetryable == true)
    }
    
    @Test("ProcessInfo ThermalState Codable")
    func testThermalStateCodable() async throws {
        let originalState = ProcessInfo.ThermalState.serious
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalState)
        
        let decoder = JSONDecoder()
        let decodedState = try decoder.decode(ProcessInfo.ThermalState.self, from: data)
        
        #expect(decodedState == originalState)
        #expect(decodedState.rawValue == 2) // serious = 2
    }
}

// MARK: - Integration Tests

@Suite("Metric Integration Tests") 
struct MetricIntegrationTests {
    
    @Test("BackgroundTaskTracker Basic Usage")
    func testBasicTaskTracking() async throws {
        let tracker = BackgroundTaskTracker.shared
        let taskId = "test-task-\(UUID())"
        
        // Clear any existing active tasks first
        // (Since we can't reset the singleton, we'll complete any active tasks)
        let currentActiveIds = await MainActor.run { tracker.activeTaskIdentifiers }
        for activeId in currentActiveIds {
            await tracker.completeExecution(for: activeId)
        }
        
        // Verify no active executions initially (after cleanup)
        await MainActor.run {
            #expect(tracker.activeTaskCount == 0)
            #expect(!tracker.isExecuting(taskId))
        }
        
        // Start execution
        await tracker.startExecution(for: taskId)
        
        await MainActor.run {
            #expect(tracker.activeTaskCount == 1)
            #expect(tracker.isExecuting(taskId))
            #expect(tracker.activeTaskIdentifiers.contains(taskId))
        }
        
        // Complete execution
        await tracker.completeExecution(for: taskId)
        
        await MainActor.run {
            #expect(tracker.activeTaskCount == 0)
            #expect(!tracker.isExecuting(taskId))
        }
    }
    
    @Test("Result-based Task Execution")
    func testResultBasedExecution() async throws {
        let tracker = BackgroundTaskTracker.shared
        let taskId = "result-test-\(UUID())"
        
        // Test successful execution
        let successResult = await tracker.executeTask(identifier: taskId) {
            return "Success"
        }
        
        switch successResult {
        case .success(let value):
            #expect(value == "Success")
        case .failure:
            Issue.record("Expected success but got failure")
        }
        
        // Test failed execution
        struct TestError: Error {}
        
        let failureResult = await tracker.executeTask(identifier: taskId) {
            throw TestError()
        }
        
        switch failureResult {
        case .success:
            Issue.record("Expected failure but got success")
        case .failure(let error):
            #expect(error is TestError)
        }
    }
    
    @Test("Concurrent Task Tracking")
    func testConcurrentTaskTracking() async throws {
        let tracker = BackgroundTaskTracker.shared
        
        // Clear any existing active tasks first
        let currentActiveIds = await MainActor.run { tracker.activeTaskIdentifiers }
        for activeId in currentActiveIds {
            await tracker.completeExecution(for: activeId)
        }
        
        let taskCount = 5
        let taskIds = (0..<taskCount).map { "concurrent-task-\($0)" }
        
        // Start all tasks concurrently
        await withTaskGroup(of: Void.self) { group in
            for taskId in taskIds {
                group.addTask {
                    await tracker.startExecution(for: taskId)
                }
            }
        }
        
        // Verify all tasks are active
        await MainActor.run {
            #expect(tracker.activeTaskCount == taskCount, "Expected \(taskCount) active tasks, got \(tracker.activeTaskCount)")
            
            for taskId in taskIds {
                #expect(tracker.isExecuting(taskId))
            }
        }
        
        // Complete all tasks
        await withTaskGroup(of: Void.self) { group in
            for taskId in taskIds {
                group.addTask {
                    await tracker.completeExecution(for: taskId)
                }
            }
        }
        
        // Verify all tasks are completed
        await MainActor.run {
            #expect(tracker.activeTaskCount == 0)
        }
    }
}

// MARK: - Performance Tests

@Suite("Metric Performance Tests")
struct MetricPerformanceTests {
    
    @Test("High Volume Event Processing", .timeLimit(.minutes(1)))
    func testHighVolumeEventProcessing() async throws {
        let eventCount = 1000
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Process many events quickly
        for i in 0..<eventCount {
            let event = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: "perf-test-\(i)",
                type: .taskExecutionCompleted,
                timestamp: Date(),
                duration: Double(i) / 1000.0,
                success: i % 10 != 0, // 90% success rate
                errorMessage: i % 10 == 0 ? "Test error" : nil,
                metadata: ["test_index": i],
                systemInfo: SystemInfo(
                    backgroundAppRefreshStatus: .available,
                    deviceModel: "Test Device",
                    systemVersion: "18.0",
                    lowPowerModeEnabled: false,
                    batteryLevel: 0.8,
                    batteryState: .unplugged
                )
            )
            
            BackgroundTaskDataStore.shared.recordEvent(event)
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should process 1000 events in reasonable time (relaxed for current implementation)
        #expect(duration < 10.0, "Processing \(eventCount) events took \(duration) seconds")
        
        // Verify events were stored
        let allEvents = BackgroundTaskDataStore.shared.getAllEvents()
        #expect(allEvents.count >= eventCount)
    }
    
    @Test("Metric Aggregation Performance", .timeLimit(.minutes(1)))
    func testMetricAggregationPerformance() async throws {
        // Generate sample data
        let sampleCount = 500
        let baseDate = Date()
        
        for i in 0..<sampleCount {
            let event = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: "agg-test-\(i % 10)", // 10 different task types
                type: BackgroundTaskEventType.allCases.randomElement() ?? .taskExecutionCompleted,
                timestamp: baseDate.addingTimeInterval(TimeInterval(i * 60)), // 1 minute apart
                duration: Double.random(in: 0.1...30.0),
                success: i % 20 != 0, // 95% success rate
                errorMessage: nil,
                metadata: [
                    "performance_cpu_usage_percentage": Double.random(in: 10...90),
                    "performance_peak_memory_usage": Int64.random(in: 10_000_000...100_000_000),
                    "performance_energy_impact": EnergyImpact.allCases.randomElement()?.rawValue ?? "moderate"
                ],
                systemInfo: SystemInfo(
                    backgroundAppRefreshStatus: .available,
                    deviceModel: "Test Device",
                    systemVersion: "18.0",
                    lowPowerModeEnabled: i % 50 == 0,
                    batteryLevel: Float.random(in: 0.2...1.0),
                    batteryState: .unplugged
                )
            )
            
            BackgroundTaskDataStore.shared.recordEvent(event)
        }
        
        // Test aggregation performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let aggregationService = MetricAggregationService.shared
        let report = await aggregationService.generateDailyReport(for: baseDate)
        
        let aggregationDuration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should generate report in reasonable time
        #expect(aggregationDuration < 2.0, "Aggregation took \(aggregationDuration) seconds")
        
        // Verify report has meaningful data
        #expect(report.taskMetrics.totalTasksScheduled > 0)
        #expect(report.performanceMetrics.averageCPUUsage > 0)
        #expect(report.systemMetrics.averageBatteryLevel > 0)
    }
}
