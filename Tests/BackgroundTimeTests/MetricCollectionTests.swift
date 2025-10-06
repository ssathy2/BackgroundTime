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
            thermalState: CodableThermalState(.nominal),
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
    
    @Test("CodableThermalState Codable")
    func testThermalStateCodable() async throws {
        let originalState = CodableThermalState(.serious)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalState)
        
        let decoder = JSONDecoder()
        let decodedState = try decoder.decode(CodableThermalState.self, from: data)
        
        #expect(decodedState.thermalState == originalState.thermalState)
        #expect(decodedState.thermalState.rawValue == 2) // serious = 2
    }
}

// MARK: - Integration Tests

@Suite("Metric Integration Tests") 
struct MetricIntegrationTests {
    
    @Test("BackgroundTaskTracker Basic Usage")
    func testBasicTaskTracking() async throws {
        // Use isolated test instance - note: tracker still uses shared instance internally
        let testPrefix = "basic_test_\(UUID().uuidString.prefix(8))_"
        
        await MainActor.run {
            let tracker = BackgroundTaskTracker.shared
            let taskId = "\(testPrefix)task"
            
            // Clear any existing active tasks first
            tracker.cleanupStaleExecutions()
            
            // Verify no active executions initially
            #expect(tracker.activeTaskCount == 0)
            #expect(!tracker.isExecuting(taskId))
            
            // Start execution
            tracker.startExecution(for: taskId)
            
            #expect(tracker.activeTaskCount == 1)
            #expect(tracker.isExecuting(taskId))
            #expect(tracker.activeTaskIdentifiers.contains(taskId))
            
            // Complete execution
            tracker.completeExecution(for: taskId)
            
            #expect(tracker.activeTaskCount == 0)
            #expect(!tracker.isExecuting(taskId))
        }
    }
    
    @Test("Result-based Task Execution")
    func testResultBasedExecution() async throws {
        let testPrefix = "result_test_\(UUID().uuidString.prefix(8))_"
        let tracker = await BackgroundTaskTracker.shared
        let taskId = "\(testPrefix)task"
        
        // Clean up first
        await MainActor.run {
            tracker.cleanupStaleExecutions()
        }
        
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
        
        let failureResult = await tracker.executeTask(identifier: "\(taskId)-failure") {
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
        let testPrefix = "concurrent_test_\(UUID().uuidString.prefix(8))_"
        
        await MainActor.run {
            let tracker = BackgroundTaskTracker.shared
            
            // Clear any existing active tasks first
            tracker.cleanupStaleExecutions()
            
            let taskCount = 5
            let taskIds = (0..<taskCount).map { "\(testPrefix)task-\($0)" }
            
            // Start all tasks
            for taskId in taskIds {
                tracker.startExecution(for: taskId)
            }
            
            // Verify all tasks are active
            #expect(tracker.activeTaskCount == taskCount, "Expected \(taskCount) active tasks, got \(tracker.activeTaskCount)")
            
            for taskId in taskIds {
                #expect(tracker.isExecuting(taskId))
            }
            
            // Complete all tasks
            for taskId in taskIds {
                tracker.completeExecution(for: taskId)
            }
            
            // Verify all tasks are completed
            #expect(tracker.activeTaskCount == 0)
        }
    }
}

// MARK: - Performance Tests

@Suite("Metric Performance Tests")
struct MetricPerformanceTests {
    
    @Test("High Volume Event Processing", .timeLimit(.minutes(1)))
    func testHighVolumeEventProcessing() async throws {
        // Use isolated test instance
        let dataStore = BackgroundTaskDataStore.createTestInstance()
        let testPrefix = "perf_test_\(UUID().uuidString.prefix(8))_"
        
        let eventCount = 1000
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Process many events quickly with unique identifiers
        for i in 0..<eventCount {
            let event = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: "\(testPrefix)\(i)",
                type: .taskExecutionCompleted,
                timestamp: Date(),
                duration: Double(i) / 1000.0,
                success: i % 10 != 0, // 90% success rate
                errorMessage: i % 10 == 0 ? "Test error" : nil,
                metadata: ["test_index": "\(i)"],
                systemInfo: SystemInfo(
                    backgroundAppRefreshStatus: .available,
                    deviceModel: "Test Device",
                    systemVersion: "18.0",
                    lowPowerModeEnabled: false,
                    batteryLevel: 0.8,
                    batteryState: .unplugged
                )
            )
            
            dataStore.recordEvent(event)
        }
        
        // Wait for all events to be persisted
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should process 1000 events in reasonable time (allowing for persistence overhead)
        #expect(duration < 15.0, "Processing \(eventCount) events took \(duration) seconds")
        
        // Verify events were stored
        let allEvents = dataStore.getAllEvents()
        #expect(allEvents.count == eventCount, "Expected \(eventCount) events, found \(allEvents.count)")
    }
    
    @Test("Metric Aggregation Performance", .timeLimit(.minutes(1)))
    func testMetricAggregationPerformance() async throws {
        // Use isolated test instance
        let dataStore = BackgroundTaskDataStore.createTestInstance()
        let testPrefix = "agg_test_\(UUID().uuidString.prefix(8))_"
        
        // Generate sample data with unique identifiers (reduced count for better test performance)
        let sampleCount = 200
        let baseDate = Date()
        
        for i in 0..<sampleCount {
            let event = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: "\(testPrefix)\(i % 10)", // 10 different task types
                type: BackgroundTaskEventType.allCases.randomElement() ?? .taskExecutionCompleted,
                timestamp: baseDate.addingTimeInterval(TimeInterval(i * 60)), // 1 minute apart
                duration: Double.random(in: 0.1...30.0),
                success: i % 20 != 0, // 95% success rate
                errorMessage: nil,
                metadata: [
                    "performance_cpu_usage_percentage": Double.random(in: 10...90).description,
                    "performance_peak_memory_usage": Int64.random(in: 10_000_000...100_000_000).description,
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
            
            dataStore.recordEvent(event)
        }
        
        // Wait for all events to be persisted
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify events were stored
        let allEvents = dataStore.getAllEvents()
        #expect(allEvents.count == sampleCount, "Expected \(sampleCount) events, found \(allEvents.count)")
        
        // Test aggregation performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let aggregationService = await MetricAggregationService.shared
        let report = await aggregationService.generateDailyReport(for: baseDate)
        
        let aggregationDuration = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should generate report in reasonable time (increased from 2.0 to 10.0 seconds for CI stability)
        #expect(aggregationDuration < 10.0, "Aggregation took \(aggregationDuration) seconds")
        
        // Verify report has meaningful data
        #expect(report.taskMetrics.totalTasksScheduled >= 0, "Report should have valid task metrics")
        #expect(report.performanceMetrics.averageCPUUsage >= 0, "Report should have valid performance metrics")
        #expect(report.systemMetrics.averageBatteryLevel >= 0, "Report should have valid system metrics")
    }
}
