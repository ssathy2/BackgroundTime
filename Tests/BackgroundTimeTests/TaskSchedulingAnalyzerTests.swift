//
//  TaskSchedulingAnalyzerTests.swift
//  BackgroundTimeTests
//
//  Created by Siddharth Sathyam on 10/8/25.
//

import Testing
import Foundation
import UIKit
@testable import BackgroundTime

// MARK: - Task Scheduling Analyzer Tests

@MainActor
@Suite("Task Scheduling Analyzer Tests")
struct TaskSchedulingAnalyzerTests {
    private let dataStore = BackgroundTaskDataStore.shared
    private let analyzer = TaskSchedulingAnalyzer()
    
    @Test("Analyze scheduling with immediate tasks")
    func analyzeImmediateTaskScheduling() async throws {
        // Clear any existing data
        await resetDataStore()
        
        let taskIdentifier = "test.immediate.task"
        let systemInfo = createMockSystemInfo()
        
        // Create scheduled events without earliestBeginDate (immediate)
        let scheduledEvent1 = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskScheduled,
            timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            success: true,
            metadata: [
                "earliestBeginDate": "none",
                "requiresNetworkConnectivity": "false",
                "requiresExternalPower": "false"
            ],
            systemInfo: systemInfo
        )
        
        let scheduledEvent2 = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskScheduled,
            timestamp: Date().addingTimeInterval(-1800), // 30 minutes ago
            success: true,
            metadata: [
                "earliestBeginDate": "none",
                "requiresNetworkConnectivity": "false",
                "requiresExternalPower": "false"
            ],
            systemInfo: systemInfo
        )
        
        // Create execution events with realistic delays
        let executedEvent1 = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskExecutionStarted,
            timestamp: scheduledEvent1.timestamp.addingTimeInterval(120), // 2 minutes delay
            success: true,
            metadata: [:],
            systemInfo: systemInfo
        )
        
        let executedEvent2 = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskExecutionStarted,
            timestamp: scheduledEvent2.timestamp.addingTimeInterval(180), // 3 minutes delay
            success: true,
            metadata: [:],
            systemInfo: systemInfo
        )
        
        // Record events
        dataStore.recordEvent(scheduledEvent1)
        dataStore.recordEvent(scheduledEvent2)
        dataStore.recordEvent(executedEvent1)
        dataStore.recordEvent(executedEvent2)
        
        // Analyze
        let analysis = analyzer.analyzeSchedulingPatterns(for: taskIdentifier)
        
        // Verify analysis results
        #expect(analysis != nil, "Analysis should be generated")
        guard let analysis = analysis else { return }
        
        #expect(analysis.taskIdentifier == taskIdentifier)
        #expect(analysis.totalScheduledTasks == 2)
        #expect(analysis.totalExecutedTasks == 2)
        #expect(analysis.executionRate == 1.0)
        
        // Verify delay calculations
        let expectedAverageDelay = (120.0 + 180.0) / 2.0 // 150 seconds
        #expect(abs(analysis.averageExecutionDelay - expectedAverageDelay) < 1.0)
        
        // Verify immediate tasks analysis
        #expect(analysis.immediateTasksAnalysis.taskCount == 2)
        #expect(analysis.delayedTasksAnalysis.taskCount == 0)
    }
    
    @Test("Analyze scheduling with delayed tasks")
    func analyzeDelayedTaskScheduling() async throws {
        await resetDataStore()
        
        let taskIdentifier = "test.delayed.task"
        let systemInfo = createMockSystemInfo()
        
        // Create scheduled events with earliestBeginDate
        let earliestBeginDate = Date().addingTimeInterval(900) // 15 minutes in future
        let scheduledEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskScheduled,
            timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            success: true,
            metadata: [
                "earliestBeginDate": earliestBeginDate.iso8601String,
                "requiresNetworkConnectivity": "false",
                "requiresExternalPower": "false"
            ],
            systemInfo: systemInfo
        )
        
        let executedEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskExecutionStarted,
            timestamp: scheduledEvent.timestamp.addingTimeInterval(1200), // 20 minutes delay
            success: true,
            metadata: [:],
            systemInfo: systemInfo
        )
        
        dataStore.recordEvent(scheduledEvent)
        dataStore.recordEvent(executedEvent)
        
        let analysis = analyzer.analyzeSchedulingPatterns(for: taskIdentifier)
        
        #expect(analysis != nil)
        guard let analysis = analysis else { return }
        
        // Verify delayed tasks analysis
        #expect(analysis.immediateTasksAnalysis.taskCount == 0)
        #expect(analysis.delayedTasksAnalysis.taskCount == 1)
        #expect(analysis.delayedTasksAnalysis.averageDelay == 1200.0)
    }
    
    @Test("Analyze scheduling with network requirements")
    func analyzeNetworkRequiredTaskScheduling() async throws {
        await resetDataStore()
        
        let taskIdentifier = "test.network.task"
        let systemInfo = createMockSystemInfo()
        
        // Network required task
        let networkScheduledEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskScheduled,
            timestamp: Date().addingTimeInterval(-3600),
            success: true,
            metadata: [
                "earliestBeginDate": "none",
                "requiresNetworkConnectivity": "true",
                "requiresExternalPower": "false"
            ],
            systemInfo: systemInfo
        )
        
        let networkExecutedEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskExecutionStarted,
            timestamp: networkScheduledEvent.timestamp.addingTimeInterval(600), // 10 minutes delay
            success: true,
            metadata: [:],
            systemInfo: systemInfo
        )
        
        // Non-network task for comparison
        let regularScheduledEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskScheduled,
            timestamp: Date().addingTimeInterval(-1800),
            success: true,
            metadata: [
                "earliestBeginDate": "none",
                "requiresNetworkConnectivity": "false",
                "requiresExternalPower": "false"
            ],
            systemInfo: systemInfo
        )
        
        let regularExecutedEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskExecutionStarted,
            timestamp: regularScheduledEvent.timestamp.addingTimeInterval(120), // 2 minutes delay
            success: true,
            metadata: [:],
            systemInfo: systemInfo
        )
        
        dataStore.recordEvent(networkScheduledEvent)
        dataStore.recordEvent(networkExecutedEvent)
        dataStore.recordEvent(regularScheduledEvent)
        dataStore.recordEvent(regularExecutedEvent)
        
        let analysis = analyzer.analyzeSchedulingPatterns(for: taskIdentifier)
        
        #expect(analysis != nil)
        guard let analysis = analysis else { return }
        
        #expect(analysis.networkRequiredAnalysis.taskCount == 1)
        #expect(analysis.networkRequiredAnalysis.averageDelay == 600.0)
        
        // Should have recommendations about network requirements
        let networkRecommendations = analysis.optimizationRecommendations.filter { 
            $0.type == .networkRequirement 
        }
        #expect(!networkRecommendations.isEmpty, "Should have network requirement recommendations")
    }
    
    @Test("Analyze scheduling with power requirements")
    func analyzePowerRequiredTaskScheduling() async throws {
        await resetDataStore()
        
        let taskIdentifier = "test.power.task"
        let systemInfo = createMockSystemInfo()
        
        // Power required task with longer delay
        let powerScheduledEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskScheduled,
            timestamp: Date().addingTimeInterval(-3600),
            success: true,
            metadata: [
                "earliestBeginDate": "none",
                "requiresNetworkConnectivity": "false",
                "requiresExternalPower": "true"
            ],
            systemInfo: systemInfo
        )
        
        let powerExecutedEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskExecutionStarted,
            timestamp: powerScheduledEvent.timestamp.addingTimeInterval(1800), // 30 minutes delay
            success: true,
            metadata: [:],
            systemInfo: systemInfo
        )
        
        // Regular task for comparison
        let regularScheduledEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskScheduled,
            timestamp: Date().addingTimeInterval(-1800),
            success: true,
            metadata: [
                "earliestBeginDate": "none",
                "requiresNetworkConnectivity": "false",
                "requiresExternalPower": "false"
            ],
            systemInfo: systemInfo
        )
        
        let regularExecutedEvent = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskIdentifier,
            type: .taskExecutionStarted,
            timestamp: regularScheduledEvent.timestamp.addingTimeInterval(300), // 5 minutes delay
            success: true,
            metadata: [:],
            systemInfo: systemInfo
        )
        
        dataStore.recordEvent(powerScheduledEvent)
        dataStore.recordEvent(powerExecutedEvent)
        dataStore.recordEvent(regularScheduledEvent)
        dataStore.recordEvent(regularExecutedEvent)
        
        let analysis = analyzer.analyzeSchedulingPatterns(for: taskIdentifier)
        
        #expect(analysis != nil)
        guard let analysis = analysis else { return }
        
        #expect(analysis.powerRequiredAnalysis.taskCount == 1)
        #expect(analysis.powerRequiredAnalysis.averageDelay == 1800.0)
        
        // Should have recommendations about power requirements
        let powerRecommendations = analysis.optimizationRecommendations.filter { 
            $0.type == .powerRequirement 
        }
        #expect(!powerRecommendations.isEmpty, "Should have power requirement recommendations")
    }
    
    @Test("Generate timing optimization recommendations")
    func generateTimingOptimizationRecommendations() async throws {
        await resetDataStore()
        
        let taskIdentifier = "test.timing.optimization"
        let systemInfo = createMockSystemInfo()
        
        // Create multiple immediate tasks with good performance
        for i in 0..<5 {
            let scheduledEvent = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: taskIdentifier,
                type: .taskScheduled,
                timestamp: Date().addingTimeInterval(-3600 - Double(i * 300)), // Spread over time
                success: true,
                metadata: [
                    "earliestBeginDate": "none",
                    "requiresNetworkConnectivity": "false",
                    "requiresExternalPower": "false"
                ],
                systemInfo: systemInfo
            )
            
            let executedEvent = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: taskIdentifier,
                type: .taskExecutionStarted,
                timestamp: scheduledEvent.timestamp.addingTimeInterval(60), // 1 minute delay
                success: true,
                metadata: [:],
                systemInfo: systemInfo
            )
            
            dataStore.recordEvent(scheduledEvent)
            dataStore.recordEvent(executedEvent)
        }
        
        // Create delayed tasks with worse performance
        for i in 0..<3 {
            let earliestBeginDate = Date().addingTimeInterval(900) // 15 minutes in future
            let scheduledEvent = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: taskIdentifier,
                type: .taskScheduled,
                timestamp: Date().addingTimeInterval(-1800 - Double(i * 300)),
                success: true,
                metadata: [
                    "earliestBeginDate": earliestBeginDate.iso8601String,
                    "requiresNetworkConnectivity": "false",
                    "requiresExternalPower": "false"
                ],
                systemInfo: systemInfo
            )
            
            let executedEvent = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: taskIdentifier,
                type: .taskExecutionStarted,
                timestamp: scheduledEvent.timestamp.addingTimeInterval(1200), // 20 minutes delay
                success: true,
                metadata: [:],
                systemInfo: systemInfo
            )
            
            dataStore.recordEvent(scheduledEvent)
            dataStore.recordEvent(executedEvent)
        }
        
        let analysis = analyzer.analyzeSchedulingPatterns(for: taskIdentifier)
        
        #expect(analysis != nil)
        guard let analysis = analysis else { return }
        
        // Should have timing optimization recommendations
        let timingRecommendations = analysis.optimizationRecommendations.filter { 
            $0.type == .timing 
        }
        #expect(!timingRecommendations.isEmpty, "Should have timing optimization recommendations")
        
        // Should recommend immediate scheduling since it performs better
        let immediateRecommendation = timingRecommendations.first { 
            $0.title.contains("Immediate") 
        }
        #expect(immediateRecommendation != nil, "Should recommend immediate scheduling")
    }
    
    @Test("Analyze all tasks returns multiple analyses")
    func analyzeAllTasksReturnsMultipleAnalyses() async throws {
        await resetDataStore()
        
        let systemInfo = createMockSystemInfo()
        let taskIdentifiers = ["task1", "task2", "task3"]
        
        // Create events for multiple tasks
        for taskIdentifier in taskIdentifiers {
            let scheduledEvent = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: taskIdentifier,
                type: .taskScheduled,
                timestamp: Date().addingTimeInterval(-3600),
                success: true,
                metadata: [
                    "earliestBeginDate": "none",
                    "requiresNetworkConnectivity": "false",
                    "requiresExternalPower": "false"
                ],
                systemInfo: systemInfo
            )
            
            let executedEvent = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: taskIdentifier,
                type: .taskExecutionStarted,
                timestamp: scheduledEvent.timestamp.addingTimeInterval(120),
                success: true,
                metadata: [:],
                systemInfo: systemInfo
            )
            
            dataStore.recordEvent(scheduledEvent)
            dataStore.recordEvent(executedEvent)
        }
        
        let analyses = analyzer.analyzeAllTasks()
        
        // Filter analyses to only include our test task identifiers
        let testAnalyses = analyses.filter { taskIdentifiers.contains($0.taskIdentifier) }
        
        #expect(testAnalyses.count == taskIdentifiers.count, "Should return analysis for each test task")
        
        let analyzedTaskIdentifiers = Set(testAnalyses.map { $0.taskIdentifier })
        let expectedTaskIdentifiers = Set(taskIdentifiers)
        #expect(analyzedTaskIdentifiers == expectedTaskIdentifiers, "Should analyze all test task identifiers")
    }
    
    // MARK: - Helper Methods
    
    private func resetDataStore() async {
        // Clear the data store for clean tests
        dataStore.clearAllEvents()
    }
    
    private func createMockSystemInfo() -> SystemInfo {
        return SystemInfo(
            backgroundAppRefreshStatus: .available,
            deviceModel: "iPhone",
            systemVersion: "17.0",
            lowPowerModeEnabled: false,
            batteryLevel: 0.8,
            batteryState: .unplugged
        )
    }
}

// MARK: - Integration Tests with BackgroundTime

@MainActor
@Suite("BackgroundTime Scheduling Analysis Integration Tests") 
struct BackgroundTimeSchedulingAnalysisIntegrationTests {
    
    @Test("BackgroundTime provides scheduling analysis")
    func backgroundTimeProvideSchedulingAnalysis() async throws {
        let backgroundTime = BackgroundTime.shared
        
        // Initialize if needed
        backgroundTime.initialize()
        
        // Test single task analysis (should handle empty data gracefully)
        let analysis = backgroundTime.analyzeTaskScheduling(for: "non.existent.task")
        #expect(analysis == nil, "Should return nil for non-existent task")
        
        // Test all tasks analysis (should handle empty data gracefully)
        let allAnalyses = backgroundTime.analyzeAllTaskScheduling()
        // Should not crash, may return empty array
    }
    
    @Test("BackgroundTime dashboard includes scheduling analyses")
    func backgroundTimeDashboardIncludesSchedulingAnalyses() async throws {
        let backgroundTime = BackgroundTime.shared
        backgroundTime.initialize()
        
        let dashboardData = backgroundTime.exportDataForDashboard()
        
        // Should include scheduling analyses (may be empty but should exist)
        #expect(dashboardData.schedulingAnalyses != nil, "Dashboard should include scheduling analyses")
    }
    
    @Test("BackgroundTime provides scheduling recommendations") 
    func backgroundTimeProvidesSchedulingRecommendations() async throws {
        let backgroundTime = BackgroundTime.shared
        backgroundTime.initialize()
        
        // Should handle non-existent task gracefully
        let recommendations = backgroundTime.getSchedulingRecommendations(for: "non.existent.task")
        #expect(recommendations.isEmpty, "Should return empty recommendations for non-existent task")
    }
}