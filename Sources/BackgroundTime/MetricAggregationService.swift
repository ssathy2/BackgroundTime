//
//  MetricAggregationService.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/25/25.
//

import Foundation
import os.log
import UIKit

// MARK: - Metric Aggregation Service

/// Service for aggregating and analyzing background task metrics across different time ranges.
/// Provides comprehensive reporting capabilities for task performance, system metrics, and error analysis.
/// This service is thread-safe and can be used from any context.
public final class MetricAggregationService: Sendable {
    nonisolated(unsafe) public static let shared = MetricAggregationService()
    
    private let logger = Logger(subsystem: "BackgroundTime", category: "MetricAggregation")
    private let dataStore = BackgroundTaskDataStore.shared
    private let calendar = Calendar.current
    
    private init() {}
    
    // MARK: - Report Generation
    
    public func generateReport(for timeRange: DateInterval) async -> MetricAggregationReport {
        logger.info("Generating metric aggregation report for range: \(timeRange.start) - \(timeRange.end)")
        
        let events = dataStore.getEventsInDateRange(from: timeRange.start, to: timeRange.end)
        
        let taskMetrics = generateTaskMetricsSummary(from: events)
        let performanceMetrics = generatePerformanceMetricsSummary(from: events)
        let systemMetrics = generateSystemMetricsSummary(from: events)
        let networkMetrics = generateNetworkMetricsSummary(from: events)
        let errorMetrics = generateErrorMetricsSummary(from: events)
        
        let report = MetricAggregationReport(
            timeRange: timeRange,
            taskMetrics: taskMetrics,
            performanceMetrics: performanceMetrics,
            systemMetrics: systemMetrics,
            networkMetrics: networkMetrics,
            errorMetrics: errorMetrics
        )
        
        logger.info("Generated report with \(events.count) events")
        return report
    }
    
    public func generateDailyReport(for date: Date = Date()) async -> MetricAggregationReport {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let timeRange = DateInterval(start: startOfDay, end: endOfDay)
        
        return await generateReport(for: timeRange)
    }
    
    public func generateWeeklyReport(for date: Date = Date()) async -> MetricAggregationReport {
        let weekRange = calendar.dateInterval(of: .weekOfYear, for: date) ?? 
                       DateInterval(start: date, duration: 7 * 24 * 60 * 60)
        
        return await generateReport(for: weekRange)
    }
    
    public func generateMonthlyReport(for date: Date = Date()) async -> MetricAggregationReport {
        let monthRange = calendar.dateInterval(of: .month, for: date) ?? 
                        DateInterval(start: date, duration: 30 * 24 * 60 * 60)
        
        return await generateReport(for: monthRange)
    }
    
    // MARK: - Task Metrics Summary
    
    private func generateTaskMetricsSummary(from events: [BackgroundTaskEvent]) -> TaskMetricsSummary {
        let scheduledEvents = events.filter { $0.type == .taskScheduled }
        let executedEvents = events.filter { $0.type == .taskExecutionStarted }
        let completedEvents = events.filter { $0.type == .taskExecutionCompleted && $0.success }
        let failedEvents = events.filter { $0.type == .taskFailed || ($0.type == .taskExecutionCompleted && !$0.success) }
        let expiredEvents = events.filter { $0.type == .taskExpired }
        
        let executionDurations = completedEvents.compactMap { $0.duration }
        let averageExecutionDuration = executionDurations.isEmpty ? 0 : 
            executionDurations.reduce(0, +) / Double(executionDurations.count)
        
        let schedulingLatencies = executedEvents.compactMap { event -> TimeInterval? in
            guard let latency = event.metadata["scheduling_latency"] as? TimeInterval else { return nil }
            return latency
        }
        let averageSchedulingLatency = schedulingLatencies.isEmpty ? 0 :
            schedulingLatencies.reduce(0, +) / Double(schedulingLatencies.count)
        
        let successRate = executedEvents.count > 0 ? 
            Double(completedEvents.count) / Double(executedEvents.count) : 0
        
        let executionTimeDistribution = Dictionary(grouping: executionDurations) { duration in
            categorizeDuration(duration)
        }.mapValues { $0.count }
        
        let hourlyExecutionPattern = Dictionary(grouping: executedEvents) { event in
            calendar.component(.hour, from: event.timestamp)
        }.mapValues { $0.count }
        
        return TaskMetricsSummary(
            totalTasksScheduled: scheduledEvents.count,
            totalTasksExecuted: executedEvents.count,
            totalTasksCompleted: completedEvents.count,
            totalTasksFailed: failedEvents.count,
            totalTasksExpired: expiredEvents.count,
            averageExecutionDuration: averageExecutionDuration,
            averageSchedulingLatency: averageSchedulingLatency,
            executionTimeDistribution: executionTimeDistribution,
            hourlyExecutionPattern: hourlyExecutionPattern
        )
    }
    
    // MARK: - Performance Metrics Summary
    
    private func generatePerformanceMetricsSummary(from events: [BackgroundTaskEvent]) -> PerformanceMetricsSummary {
        let performanceEvents = events.filter { event in
            event.metadata.keys.contains { $0.hasPrefix("performance_") }
        }
        
        let cpuUsages = performanceEvents.compactMap { event -> Double? in
            event.metadata["performance_cpu_usage_percentage"] as? Double
        }
        
        let memoryUsages = performanceEvents.compactMap { event -> Int64? in
            event.metadata["performance_peak_memory_usage"] as? Int64
        }
        
        let energyImpacts = performanceEvents.compactMap { event -> EnergyImpact? in
            guard let rawValue = event.metadata["performance_energy_impact"] as? String else { return nil }
            return EnergyImpact(rawValue: rawValue)
        }
        
        let averageCPUUsage = cpuUsages.isEmpty ? 0 : cpuUsages.reduce(0, +) / Double(cpuUsages.count)
        let peakCPUUsage = cpuUsages.max() ?? 0
        let averageMemoryUsage = memoryUsages.isEmpty ? 0 : memoryUsages.reduce(0, +) / Int64(memoryUsages.count)
        let peakMemoryUsage = memoryUsages.max() ?? 0
        
        let energyImpactDistribution = Dictionary(grouping: energyImpacts, by: { $0.rawValue })
            .mapValues { $0.count }
        
        let averageEnergyImpactScore = energyImpacts.isEmpty ? 0 :
            Double(energyImpacts.map { $0.score }.reduce(0, +)) / Double(energyImpacts.count)
        
        let highPerformanceTasksCount = energyImpacts.filter { $0.score >= 4 }.count
        let lowPerformanceTasksCount = energyImpacts.filter { $0.score <= 2 }.count
        
        return PerformanceMetricsSummary(
            averageCPUUsage: averageCPUUsage,
            peakCPUUsage: peakCPUUsage,
            averageMemoryUsage: averageMemoryUsage,
            peakMemoryUsage: peakMemoryUsage,
            energyImpactDistribution: energyImpactDistribution,
            averageEnergyImpactScore: averageEnergyImpactScore,
            highPerformanceTasksCount: highPerformanceTasksCount,
            lowPerformanceTasksCount: lowPerformanceTasksCount
        )
    }
    
    // MARK: - System Metrics Summary
    
    private func generateSystemMetricsSummary(from events: [BackgroundTaskEvent]) -> SystemMetricsSummary {
        let systemInfos = events.map { $0.systemInfo }
        
        let batteryLevels = systemInfos.map { $0.batteryLevel }.filter { $0 >= 0 }
        let averageBatteryLevel = batteryLevels.isEmpty ? 0 : 
            batteryLevels.reduce(0, +) / Float(batteryLevels.count)
        
        let lowPowerModeActivations = systemInfos.filter { $0.lowPowerModeEnabled }.count
        
        let thermalStates = events.compactMap { event -> String? in
            event.metadata["system_thermal_state"] as? String
        }
        let thermalStateDistribution = Dictionary(grouping: thermalStates, by: { $0 })
            .mapValues { $0.count }
        
        let memoryStatuses = events.compactMap { event -> String? in
            event.metadata["system_memory_status"] as? String
        }
        let memoryPressureEvents = memoryStatuses.filter { $0 == "low" || $0 == "critical" }.count
        
        let diskSpaceEvents = events.compactMap { event -> Int64? in
            event.metadata["system_disk_space_available"] as? Int64
        }
        let diskSpaceCriticalEvents = diskSpaceEvents.filter { $0 < 1_000_000_000 }.count // Less than 1GB
        
        let chargingStates = systemInfos.map { $0.batteryState == .charging }
        let chargingTimePercentage = chargingStates.isEmpty ? 0 :
            Double(chargingStates.filter { $0 }.count) / Double(chargingStates.count) * 100
        
        let optimalConditions = events.filter { event in
            let batteryOK = event.systemInfo.batteryLevel > 0.2
            let thermalOK = (event.metadata["system_thermal_state"]) == "nominal"
            let memoryOK = (event.metadata["system_memory_status"]) != "critical"
            let powerOK = !event.systemInfo.lowPowerModeEnabled
            
            return batteryOK && thermalOK && memoryOK && powerOK
        }
        
        let optimalConditionsPercentage = events.isEmpty ? 0 :
            Double(optimalConditions.count) / Double(events.count) * 100
        
        return SystemMetricsSummary(
            averageBatteryLevel: averageBatteryLevel,
            lowPowerModeActivations: lowPowerModeActivations,
            thermalStateDistribution: thermalStateDistribution,
            memoryPressureEvents: memoryPressureEvents,
            diskSpaceCriticalEvents: diskSpaceCriticalEvents,
            chargingTimePercentage: chargingTimePercentage,
            optimalConditionsPercentage: optimalConditionsPercentage
        )
    }
    
    // MARK: - Network Metrics Summary
    
    private func generateNetworkMetricsSummary(from events: [BackgroundTaskEvent]) -> NetworkMetricsSummary {
        let networkEvents = events.filter { event in
            event.metadata.keys.contains { $0.hasPrefix("network_") }
        }
        
        let requestCounts = networkEvents.compactMap { event -> Int? in
            event.metadata["network_request_count"] as? Int
        }
        let totalNetworkRequests = requestCounts.reduce(0, +)
        
        let bytesTransferred = networkEvents.compactMap { event -> Int64? in
            event.metadata["network_total_bytes_transferred"] as? Int64
        }
        let totalDataTransferred = bytesTransferred.reduce(0, +)
        
        let latencies = networkEvents.compactMap { event -> TimeInterval? in
            event.metadata["network_average_latency"] as? TimeInterval
        }
        let averageLatency = latencies.isEmpty ? 0 : latencies.reduce(0, +) / Double(latencies.count)
        
        let connectionFailures = networkEvents.compactMap { event -> Int? in
            event.metadata["network_connection_failures"] as? Int
        }
        let totalFailures = connectionFailures.reduce(0, +)
        let connectionFailureRate = totalNetworkRequests > 0 ? 
            Double(totalFailures) / Double(totalNetworkRequests) : 0
        
        let reliabilityCategories = networkEvents.compactMap { event -> String? in
            event.metadata["network_reliability_category"] as? String
        }
        let reliabilityDistribution = Dictionary(grouping: reliabilityCategories, by: { $0 })
            .mapValues { $0.count }
        
        let dataUsageCategories = networkEvents.compactMap { event -> String? in
            event.metadata["network_data_usage_category"] as? String
        }
        let dataUsageDistribution = Dictionary(grouping: dataUsageCategories, by: { $0 })
            .mapValues { $0.count }
        
        // Calculate network unavailable time from events that failed due to network issues
        let networkFailureEvents = events.filter { event in
            guard let errorCategory = event.metadata["error_category"] as? String else { return false }
            return errorCategory == "network"
        }
        let networkUnavailableTime = networkFailureEvents.compactMap { $0.duration }.reduce(0, +)
        
        return NetworkMetricsSummary(
            totalNetworkRequests: totalNetworkRequests,
            totalDataTransferred: totalDataTransferred,
            averageLatency: averageLatency,
            connectionFailureRate: connectionFailureRate,
            reliabilityDistribution: reliabilityDistribution,
            dataUsageDistribution: dataUsageDistribution,
            networkUnavailableTime: networkUnavailableTime
        )
    }
    
    // MARK: - Error Metrics Summary
    
    private func generateErrorMetricsSummary(from events: [BackgroundTaskEvent]) -> ErrorMetricsSummary {
        let errorEvents = events.filter { !$0.success || $0.errorMessage != nil }
        
        let errorCategories = errorEvents.compactMap { event -> String? in
            event.metadata["error_category"] as? String
        }
        let errorCategoryDistribution = Dictionary(grouping: errorCategories, by: { $0 })
            .mapValues { $0.count }
        
        let errorSeverities = errorEvents.compactMap { event -> String? in
            event.metadata["error_severity"] as? String
        }
        let errorSeverityDistribution = Dictionary(grouping: errorSeverities, by: { $0 })
            .mapValues { $0.count }
        
        let retryableErrors = errorEvents.filter { event in
            // This would be determined by the error categorization
            guard let category = event.metadata["error_category"] as? String else { return false }
            return ["network", "timeout", "system", "quota"].contains(category)
        }
        let retryableErrorsCount = retryableErrors.count
        
        let criticalErrors = errorEvents.filter { event in
            guard let severity = event.metadata["error_severity"] as? String else { return false }
            return severity == "critical"
        }
        let criticalErrorsCount = criticalErrors.count
        
        let errorCodes = errorEvents.compactMap { event -> String? in
            event.metadata["error_code"] as? String
        }
        let mostCommonErrors = Dictionary(grouping: errorCodes, by: { $0 })
            .mapValues { $0.count }
        
        // Generate error trends by day
        let errorTrends = Dictionary(grouping: errorCategories, by: { $0 })
            .mapValues { _ in
                // Group by day and count occurrences
                Dictionary(grouping: errorEvents, by: { 
                    calendar.startOfDay(for: $0.timestamp)
                }).mapValues { $0.count }
            }
        
        return ErrorMetricsSummary(
            totalErrors: errorEvents.count,
            errorCategoryDistribution: errorCategoryDistribution,
            errorSeverityDistribution: errorSeverityDistribution,
            retryableErrorsCount: retryableErrorsCount,
            criticalErrorsCount: criticalErrorsCount,
            mostCommonErrors: mostCommonErrors,
            errorTrends: errorTrends
        )
    }
    
    // MARK: - Helper Methods
    
    private func categorizeDuration(_ duration: TimeInterval) -> String {
        switch duration {
        case 0..<1: return "instant"
        case 1..<10: return "quick"
        case 10..<60: return "moderate"
        case 60..<300: return "long"
        default: return "extended"
        }
    }
    
    // MARK: - Export Functions
    
    public func exportReportAsJSON(_ report: MetricAggregationReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(report)
    }
    
    public func exportReportAsCSV(_ report: MetricAggregationReport) -> String {
        var csvContent = "Metric Category,Metric Name,Value,Unit\n"
        
        // Task metrics
        csvContent += "Task,Total Scheduled,\(report.taskMetrics.totalTasksScheduled),count\n"
        csvContent += "Task,Total Executed,\(report.taskMetrics.totalTasksExecuted),count\n"
        csvContent += "Task,Total Completed,\(report.taskMetrics.totalTasksCompleted),count\n"
        csvContent += "Task,Total Failed,\(report.taskMetrics.totalTasksFailed),count\n"
        csvContent += "Task,Success Rate,\(String(format: "%.2f", report.taskMetrics.successRate * 100)),percentage\n"
        csvContent += "Task,Average Execution Duration,\(String(format: "%.3f", report.taskMetrics.averageExecutionDuration)),seconds\n"
        csvContent += "Task,Average Scheduling Latency,\(String(format: "%.3f", report.taskMetrics.averageSchedulingLatency)),seconds\n"
        
        // Performance metrics
        csvContent += "Performance,Average CPU Usage,\(String(format: "%.2f", report.performanceMetrics.averageCPUUsage)),percentage\n"
        csvContent += "Performance,Peak CPU Usage,\(String(format: "%.2f", report.performanceMetrics.peakCPUUsage)),percentage\n"
        csvContent += "Performance,Average Memory Usage,\(report.performanceMetrics.averageMemoryUsage),bytes\n"
        csvContent += "Performance,Peak Memory Usage,\(report.performanceMetrics.peakMemoryUsage),bytes\n"
        csvContent += "Performance,Average Energy Impact Score,\(String(format: "%.2f", report.performanceMetrics.averageEnergyImpactScore)),score\n"
        
        // System metrics
        csvContent += "System,Average Battery Level,\(String(format: "%.2f", report.systemMetrics.averageBatteryLevel * 100)),percentage\n"
        csvContent += "System,Low Power Mode Activations,\(report.systemMetrics.lowPowerModeActivations),count\n"
        csvContent += "System,Memory Pressure Events,\(report.systemMetrics.memoryPressureEvents),count\n"
        csvContent += "System,Charging Time,\(String(format: "%.2f", report.systemMetrics.chargingTimePercentage)),percentage\n"
        csvContent += "System,Optimal Conditions,\(String(format: "%.2f", report.systemMetrics.optimalConditionsPercentage)),percentage\n"
        
        // Network metrics
        csvContent += "Network,Total Requests,\(report.networkMetrics.totalNetworkRequests),count\n"
        csvContent += "Network,Total Data Transferred,\(report.networkMetrics.totalDataTransferred),bytes\n"
        csvContent += "Network,Average Latency,\(String(format: "%.3f", report.networkMetrics.averageLatency)),seconds\n"
        csvContent += "Network,Connection Failure Rate,\(String(format: "%.2f", report.networkMetrics.connectionFailureRate * 100)),percentage\n"
        
        // Error metrics
        csvContent += "Error,Total Errors,\(report.errorMetrics.totalErrors),count\n"
        csvContent += "Error,Retryable Errors,\(report.errorMetrics.retryableErrorsCount),count\n"
        csvContent += "Error,Critical Errors,\(report.errorMetrics.criticalErrorsCount),count\n"
        
        return csvContent
    }
}
