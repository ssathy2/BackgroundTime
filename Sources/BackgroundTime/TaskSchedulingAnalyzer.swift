//
//  TaskSchedulingAnalyzer.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 10/8/25.
//

import Foundation
import os.log

// MARK: - Task Scheduling Analysis Models

public struct TaskSchedulingAnalysis: Codable, Sendable, Identifiable {
    public let taskIdentifier: String
    public let analysisDate: Date
    public let totalScheduledTasks: Int
    public let totalExecutedTasks: Int
    public let executionRate: Double
    
    // Identifiable conformance
    public var id: String { taskIdentifier }
    
    // Delay analysis
    public let averageExecutionDelay: TimeInterval
    public let medianExecutionDelay: TimeInterval
    public let minExecutionDelay: TimeInterval
    public let maxExecutionDelay: TimeInterval
    
    // Property-based analysis
    public let immediateTasksAnalysis: PropertyBasedAnalysis
    public let delayedTasksAnalysis: PropertyBasedAnalysis
    public let networkRequiredAnalysis: PropertyBasedAnalysis
    public let powerRequiredAnalysis: PropertyBasedAnalysis
    
    // Recommendations
    public let optimizationRecommendations: [SchedulingRecommendation]
    
    public init(
        taskIdentifier: String,
        analysisDate: Date = Date(),
        totalScheduledTasks: Int,
        totalExecutedTasks: Int,
        executionRate: Double,
        averageExecutionDelay: TimeInterval,
        medianExecutionDelay: TimeInterval,
        minExecutionDelay: TimeInterval,
        maxExecutionDelay: TimeInterval,
        immediateTasksAnalysis: PropertyBasedAnalysis,
        delayedTasksAnalysis: PropertyBasedAnalysis,
        networkRequiredAnalysis: PropertyBasedAnalysis,
        powerRequiredAnalysis: PropertyBasedAnalysis,
        optimizationRecommendations: [SchedulingRecommendation]
    ) {
        self.taskIdentifier = taskIdentifier
        self.analysisDate = analysisDate
        self.totalScheduledTasks = totalScheduledTasks
        self.totalExecutedTasks = totalExecutedTasks
        self.executionRate = executionRate
        self.averageExecutionDelay = averageExecutionDelay
        self.medianExecutionDelay = medianExecutionDelay
        self.minExecutionDelay = minExecutionDelay
        self.maxExecutionDelay = maxExecutionDelay
        self.immediateTasksAnalysis = immediateTasksAnalysis
        self.delayedTasksAnalysis = delayedTasksAnalysis
        self.networkRequiredAnalysis = networkRequiredAnalysis
        self.powerRequiredAnalysis = powerRequiredAnalysis
        self.optimizationRecommendations = optimizationRecommendations
    }
}

public struct PropertyBasedAnalysis: Codable, Sendable {
    public let taskCount: Int
    public let averageDelay: TimeInterval
    public let medianDelay: TimeInterval
    public let executionRate: Double
    public let optimalTimeWindows: [TimeWindow]
    
    public init(
        taskCount: Int,
        averageDelay: TimeInterval,
        medianDelay: TimeInterval,
        executionRate: Double,
        optimalTimeWindows: [TimeWindow]
    ) {
        self.taskCount = taskCount
        self.averageDelay = averageDelay
        self.medianDelay = medianDelay
        self.executionRate = executionRate
        self.optimalTimeWindows = optimalTimeWindows
    }
}

public struct TimeWindow: Codable, Sendable {
    public let startHour: Int // 0-23
    public let endHour: Int   // 0-23
    public let averageDelay: TimeInterval
    public let executionRate: Double
    public let sampleSize: Int
    
    public var description: String {
        let startTime = String(format: "%02d:00", startHour)
        let endTime = String(format: "%02d:00", endHour)
        return "\(startTime) - \(endTime)"
    }
    
    public init(
        startHour: Int,
        endHour: Int,
        averageDelay: TimeInterval,
        executionRate: Double,
        sampleSize: Int
    ) {
        self.startHour = startHour
        self.endHour = endHour
        self.averageDelay = averageDelay
        self.executionRate = executionRate
        self.sampleSize = sampleSize
    }
}

public struct SchedulingRecommendation: Codable, Sendable, Identifiable {
    public let id: UUID
    public let type: RecommendationType
    public let title: String
    public let description: String
    public let priority: RecommendationPriority
    public let potentialImprovement: String
    public let implementation: String
    
    public init(
        id: UUID = UUID(),
        type: RecommendationType,
        title: String,
        description: String,
        priority: RecommendationPriority,
        potentialImprovement: String,
        implementation: String
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.priority = priority
        self.potentialImprovement = potentialImprovement
        self.implementation = implementation
    }
}

public enum RecommendationType: String, Codable, CaseIterable, Sendable {
    case timing = "timing"
    case networkRequirement = "network_requirement"
    case powerRequirement = "power_requirement"
    case frequency = "frequency"
    case systemConditions = "system_conditions"
    
    public var displayName: String {
        switch self {
        case .timing: return "Timing Optimization"
        case .networkRequirement: return "Network Requirements"
        case .powerRequirement: return "Power Requirements"
        case .frequency: return "Task Frequency"
        case .systemConditions: return "System Conditions"
        }
    }
}

public enum RecommendationPriority: String, Codable, CaseIterable, Sendable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    public var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

// MARK: - Task Scheduling Analyzer

@MainActor
public final class TaskSchedulingAnalyzer {
    private let logger = Logger(subsystem: "BackgroundTime", category: "TaskSchedulingAnalyzer")
    private let dataStore = BackgroundTaskDataStore.shared
    
    public init() {}
    
    /// Analyze scheduling patterns for a specific task identifier
    public func analyzeSchedulingPatterns(for taskIdentifier: String) -> TaskSchedulingAnalysis? {
        let events = dataStore.getAllEvents().filter { $0.taskIdentifier == taskIdentifier }
        
        guard !events.isEmpty else {
            logWarning("No events found for task identifier: \(taskIdentifier)")
            return nil
        }
        
        // Group events by task lifecycle
        let scheduledEvents = events.filter { $0.type == .taskScheduled }
        let executedEvents = events.filter { $0.type == .taskExecutionStarted }
        
        guard !scheduledEvents.isEmpty else {
            logWarning("No scheduled events found for task identifier: \(taskIdentifier)")
            return nil
        }
        
        // Calculate execution delays
        let executionDelays = calculateExecutionDelays(scheduled: scheduledEvents, executed: executedEvents)
        
        guard !executionDelays.isEmpty else {
            logInfo("No matching execution events found for scheduled tasks")
            return TaskSchedulingAnalysis(
                taskIdentifier: taskIdentifier,
                totalScheduledTasks: scheduledEvents.count,
                totalExecutedTasks: 0,
                executionRate: 0.0,
                averageExecutionDelay: 0,
                medianExecutionDelay: 0,
                minExecutionDelay: 0,
                maxExecutionDelay: 0,
                immediateTasksAnalysis: PropertyBasedAnalysis(taskCount: 0, averageDelay: 0, medianDelay: 0, executionRate: 0, optimalTimeWindows: []),
                delayedTasksAnalysis: PropertyBasedAnalysis(taskCount: 0, averageDelay: 0, medianDelay: 0, executionRate: 0, optimalTimeWindows: []),
                networkRequiredAnalysis: PropertyBasedAnalysis(taskCount: 0, averageDelay: 0, medianDelay: 0, executionRate: 0, optimalTimeWindows: []),
                powerRequiredAnalysis: PropertyBasedAnalysis(taskCount: 0, averageDelay: 0, medianDelay: 0, executionRate: 0, optimalTimeWindows: []),
                optimizationRecommendations: []
            )
        }
        
        // Calculate basic statistics
        let delays = executionDelays.map { $0.delay }
        let averageDelay = delays.reduce(0, +) / Double(delays.count)
        let sortedDelays = delays.sorted()
        let medianDelay = calculateMedian(from: sortedDelays)
        let minDelay = sortedDelays.first ?? 0
        let maxDelay = sortedDelays.last ?? 0
        let executionRate = Double(executedEvents.count) / Double(scheduledEvents.count)
        
        // Analyze based on scheduling properties
        let immediateTasksAnalysis = analyzeByEarliestBeginDate(executionDelays, immediate: true)
        let delayedTasksAnalysis = analyzeByEarliestBeginDate(executionDelays, immediate: false)
        let networkRequiredAnalysis = analyzeByNetworkRequirement(executionDelays, required: true)
        let powerRequiredAnalysis = analyzeByPowerRequirement(executionDelays, required: true)
        
        // Generate recommendations
        let recommendations = generateRecommendations(
            taskIdentifier: taskIdentifier,
            executionDelays: executionDelays,
            immediateAnalysis: immediateTasksAnalysis,
            delayedAnalysis: delayedTasksAnalysis,
            networkAnalysis: networkRequiredAnalysis,
            powerAnalysis: powerRequiredAnalysis
        )
        
        return TaskSchedulingAnalysis(
            taskIdentifier: taskIdentifier,
            totalScheduledTasks: scheduledEvents.count,
            totalExecutedTasks: executedEvents.count,
            executionRate: executionRate,
            averageExecutionDelay: averageDelay,
            medianExecutionDelay: medianDelay,
            minExecutionDelay: minDelay,
            maxExecutionDelay: maxDelay,
            immediateTasksAnalysis: immediateTasksAnalysis,
            delayedTasksAnalysis: delayedTasksAnalysis,
            networkRequiredAnalysis: networkRequiredAnalysis,
            powerRequiredAnalysis: powerRequiredAnalysis,
            optimizationRecommendations: recommendations
        )
    }
    
    /// Analyze all task identifiers and provide optimization insights
    public func analyzeAllTasks() -> [TaskSchedulingAnalysis] {
        let allEvents = dataStore.getAllEvents()
        let taskIdentifiers = Set(allEvents.map { $0.taskIdentifier })
            .filter { !$0.isEmpty && 
                     $0 != "SDK_EVENT" && 
                     $0 != "ALL_TASKS" &&
                     !$0.hasPrefix("swizzling-registration-test") &&
                     !$0.hasPrefix("test-init-task") &&
                     !$0.contains("-test-") // Filter out other test artifacts
            }
        
        return taskIdentifiers.compactMap { identifier in
            analyzeSchedulingPatterns(for: identifier)
        }
    }
    
    // MARK: - Private Analysis Methods
    
    private func calculateExecutionDelays(scheduled: [BackgroundTaskEvent], executed: [BackgroundTaskEvent]) -> [ExecutionDelay] {
        var delays: [ExecutionDelay] = []
        
        for scheduledEvent in scheduled {
            // Find the next execution event after this scheduled event
            if let executedEvent = executed.first(where: { executedEvent in
                executedEvent.timestamp >= scheduledEvent.timestamp &&
                executedEvent.taskIdentifier == scheduledEvent.taskIdentifier
            }) {
                let delay = executedEvent.timestamp.timeIntervalSince(scheduledEvent.timestamp)
                
                delays.append(ExecutionDelay(
                    scheduledEvent: scheduledEvent,
                    executedEvent: executedEvent,
                    delay: delay
                ))
            }
        }
        
        return delays
    }
    
    private func analyzeByEarliestBeginDate(_ delays: [ExecutionDelay], immediate: Bool) -> PropertyBasedAnalysis {
        let filteredDelays = delays.filter { delay in
            let earliestBeginDateStr = delay.scheduledEvent.metadata["earliestBeginDate"] ?? "none"
            let hasEarliestBeginDate = earliestBeginDateStr != "none"
            return immediate ? !hasEarliestBeginDate : hasEarliestBeginDate
        }
        
        guard !filteredDelays.isEmpty else {
            return PropertyBasedAnalysis(taskCount: 0, averageDelay: 0, medianDelay: 0, executionRate: 0, optimalTimeWindows: [])
        }
        
        let delayValues = filteredDelays.map { $0.delay }
        let averageDelay = delayValues.reduce(0, +) / Double(delayValues.count)
        let medianDelay = calculateMedian(from: delayValues.sorted())
        let timeWindows = calculateOptimalTimeWindows(from: filteredDelays)
        
        return PropertyBasedAnalysis(
            taskCount: filteredDelays.count,
            averageDelay: averageDelay,
            medianDelay: medianDelay,
            executionRate: 1.0, // These are already matched scheduled->executed pairs
            optimalTimeWindows: timeWindows
        )
    }
    
    private func analyzeByNetworkRequirement(_ delays: [ExecutionDelay], required: Bool) -> PropertyBasedAnalysis {
        let filteredDelays = delays.filter { delay in
            let networkRequired = delay.scheduledEvent.metadata["requiresNetworkConnectivity"] == "true"
            return networkRequired == required
        }
        
        return createPropertyAnalysis(from: filteredDelays)
    }
    
    private func analyzeByPowerRequirement(_ delays: [ExecutionDelay], required: Bool) -> PropertyBasedAnalysis {
        let filteredDelays = delays.filter { delay in
            let powerRequired = delay.scheduledEvent.metadata["requiresExternalPower"] == "true"
            return powerRequired == required
        }
        
        return createPropertyAnalysis(from: filteredDelays)
    }
    
    private func createPropertyAnalysis(from delays: [ExecutionDelay]) -> PropertyBasedAnalysis {
        guard !delays.isEmpty else {
            return PropertyBasedAnalysis(taskCount: 0, averageDelay: 0, medianDelay: 0, executionRate: 0, optimalTimeWindows: [])
        }
        
        let delayValues = delays.map { $0.delay }
        let averageDelay = delayValues.reduce(0, +) / Double(delayValues.count)
        let medianDelay = calculateMedian(from: delayValues.sorted())
        let timeWindows = calculateOptimalTimeWindows(from: delays)
        
        return PropertyBasedAnalysis(
            taskCount: delays.count,
            averageDelay: averageDelay,
            medianDelay: medianDelay,
            executionRate: 1.0,
            optimalTimeWindows: timeWindows
        )
    }
    
    private func calculateOptimalTimeWindows(from delays: [ExecutionDelay]) -> [TimeWindow] {
        // Group delays by hour of day when they were scheduled
        var hourlyData: [Int: [TimeInterval]] = [:]
        
        for delay in delays {
            let hour = Calendar.current.component(.hour, from: delay.scheduledEvent.timestamp)
            hourlyData[hour, default: []].append(delay.delay)
        }
        
        // Calculate statistics for each hour and create time windows
        return hourlyData.compactMap { (hour, delayList) in
            guard delayList.count >= 3 else { return nil } // Need at least 3 samples
            
            let averageDelay = delayList.reduce(0, +) / Double(delayList.count)
            let executionRate = 1.0 // These are matched pairs
            
            return TimeWindow(
                startHour: hour,
                endHour: (hour + 1) % 24,
                averageDelay: averageDelay,
                executionRate: executionRate,
                sampleSize: delayList.count
            )
        }.sorted { $0.averageDelay < $1.averageDelay }
    }
    
    private func calculateMedian(from sortedArray: [TimeInterval]) -> TimeInterval {
        guard !sortedArray.isEmpty else { return 0 }
        
        let count = sortedArray.count
        if count % 2 == 0 {
            return (sortedArray[count/2 - 1] + sortedArray[count/2]) / 2
        } else {
            return sortedArray[count/2]
        }
    }
    
    private func generateRecommendations(
        taskIdentifier: String,
        executionDelays: [ExecutionDelay],
        immediateAnalysis: PropertyBasedAnalysis,
        delayedAnalysis: PropertyBasedAnalysis,
        networkAnalysis: PropertyBasedAnalysis,
        powerAnalysis: PropertyBasedAnalysis
    ) -> [SchedulingRecommendation] {
        
        var recommendations: [SchedulingRecommendation] = []
        
        // Analyze immediate vs delayed tasks
        if immediateAnalysis.taskCount > 0 && delayedAnalysis.taskCount > 0 {
            if immediateAnalysis.averageDelay < delayedAnalysis.averageDelay {
                recommendations.append(SchedulingRecommendation(
                    type: .timing,
                    title: "Consider Immediate Scheduling",
                    description: "Tasks scheduled without earliestBeginDate execute \(formatTimeInterval(delayedAnalysis.averageDelay - immediateAnalysis.averageDelay)) faster on average.",
                    priority: .medium,
                    potentialImprovement: "Reduce average delay by \(formatTimeInterval(delayedAnalysis.averageDelay - immediateAnalysis.averageDelay))",
                    implementation: "Remove or reduce earliestBeginDate for time-sensitive tasks"
                ))
            } else if delayedAnalysis.averageDelay < immediateAnalysis.averageDelay * 1.5 {
                recommendations.append(SchedulingRecommendation(
                    type: .timing,
                    title: "Optimize earliestBeginDate",
                    description: "Using earliestBeginDate provides more consistent execution timing with only \(formatTimeInterval(delayedAnalysis.averageDelay - immediateAnalysis.averageDelay)) additional delay.",
                    priority: .low,
                    potentialImprovement: "More predictable task execution",
                    implementation: "Set earliestBeginDate to 15-30 minutes in the future for optimal system scheduling"
                ))
            }
        }
        
        // Analyze network requirements
        if networkAnalysis.taskCount > 0 {
            let nonNetworkDelays = executionDelays.filter { 
                $0.scheduledEvent.metadata["requiresNetworkConnectivity"] != "true"
            }
            
            if !nonNetworkDelays.isEmpty {
                let nonNetworkAverage = nonNetworkDelays.map { $0.delay }.reduce(0, +) / Double(nonNetworkDelays.count)
                
                if networkAnalysis.averageDelay > nonNetworkAverage * 2 {
                    recommendations.append(SchedulingRecommendation(
                        type: .networkRequirement,
                        title: "Review Network Requirement",
                        description: "Tasks requiring network connectivity have \(formatTimeInterval(networkAnalysis.averageDelay - nonNetworkAverage)) longer delays on average.",
                        priority: .medium,
                        potentialImprovement: "Reduce delay by \(formatTimeInterval(networkAnalysis.averageDelay - nonNetworkAverage))",
                        implementation: "Only set requiresNetworkConnectivity = true when absolutely necessary"
                    ))
                }
            }
        }
        
        // Analyze power requirements
        if powerAnalysis.taskCount > 0 {
            let nonPowerDelays = executionDelays.filter { 
                $0.scheduledEvent.metadata["requiresExternalPower"] != "true"
            }
            
            if !nonPowerDelays.isEmpty {
                let nonPowerAverage = nonPowerDelays.map { $0.delay }.reduce(0, +) / Double(nonPowerDelays.count)
                
                if powerAnalysis.averageDelay > nonPowerAverage * 3 {
                    recommendations.append(SchedulingRecommendation(
                        type: .powerRequirement,
                        title: "Reconsider External Power Requirement",
                        description: "Tasks requiring external power have significantly longer delays (\(formatTimeInterval(powerAnalysis.averageDelay)) vs \(formatTimeInterval(nonPowerAverage))).",
                        priority: .high,
                        potentialImprovement: "Reduce delay by \(formatTimeInterval(powerAnalysis.averageDelay - nonPowerAverage))",
                        implementation: "Only set requiresExternalPower = true for power-intensive operations"
                    ))
                }
            }
        }
        
        // Analyze optimal time windows
        if let bestWindow = immediateAnalysis.optimalTimeWindows.first ?? delayedAnalysis.optimalTimeWindows.first {
            if bestWindow.averageDelay < executionDelays.map({ $0.delay }).reduce(0, +) / Double(executionDelays.count) * 0.5 {
                recommendations.append(SchedulingRecommendation(
                    type: .timing,
                    title: "Optimize Scheduling Time",
                    description: "Tasks scheduled during \(bestWindow.description) execute \(formatTimeInterval(bestWindow.averageDelay)) faster on average.",
                    priority: .medium,
                    potentialImprovement: "Schedule during optimal time window",
                    implementation: "Set earliestBeginDate to target the \(bestWindow.description) time window"
                ))
            }
        }
        
        return recommendations
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        if interval < 60 {
            return String(format: "%.1f seconds", interval)
        } else if interval < 3600 {
            return String(format: "%.1f minutes", interval / 60)
        } else {
            return String(format: "%.1f hours", interval / 3600)
        }
    }
}

// MARK: - Helper Models

private struct ExecutionDelay {
    let scheduledEvent: BackgroundTaskEvent
    let executedEvent: BackgroundTaskEvent
    let delay: TimeInterval
}
