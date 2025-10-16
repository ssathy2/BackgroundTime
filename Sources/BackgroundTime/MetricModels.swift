//
//  MetricModels.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/25/25.
//

import Foundation
import UIKit
import BackgroundTasks

// MARK: - Performance Metrics

public struct PerformanceMetrics: Codable {
    public let duration: TimeInterval
    public let cpuTime: TimeInterval
    public let cpuUsagePercentage: Double
    public let peakMemoryUsage: Int64
    public let energyImpact: EnergyImpact
    
    public func toDictionary() -> [String: Any] {
        return [
            "performance_duration": duration,
            "performance_cpu_time": cpuTime,
            "performance_cpu_usage_percentage": cpuUsagePercentage,
            "performance_peak_memory_usage": peakMemoryUsage,
            "performance_energy_impact": energyImpact.rawValue,
            "performance_energy_impact_score": energyImpact.score
        ]
    }
}

public enum EnergyImpact: String, Codable, CaseIterable {
    case veryLow = "very_low"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case veryHigh = "very_high"
    
    public var score: Int {
        switch self {
        case .veryLow: return 1
        case .low: return 2
        case .moderate: return 3
        case .high: return 4
        case .veryHigh: return 5
        }
    }
    
    public var displayName: String {
        switch self {
        case .veryLow: return "Very Low"
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }
}

// MARK: - System Resource Metrics

public struct SystemResourceMetrics: Codable {
    public let batteryLevel: Float
    public let isCharging: Bool
    public let isLowPowerModeEnabled: Bool
    public let thermalState: CodableThermalState
    public let availableMemoryPercentage: Double
    public let diskSpaceAvailable: Int64
    
    public func toDictionary() -> [String: Any] {
        return [
            "system_battery_level": batteryLevel,
            "system_is_charging": isCharging,
            "system_low_power_mode": isLowPowerModeEnabled,
            "system_thermal_state": thermalStateString,
            "system_available_memory_percentage": availableMemoryPercentage,
            "system_disk_space_available": diskSpaceAvailable,
            "system_memory_status": memoryStatus,
            "system_power_status": powerStatus
        ]
    }
    
    private var thermalStateString: String {
        switch thermalState.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
    
    private var memoryStatus: String {
        switch availableMemoryPercentage {
        case 50...: return "good"
        case 20..<50: return "moderate"
        case 10..<20: return "low"
        default: return "critical"
        }
    }
    
    private var powerStatus: String {
        if isCharging { return "charging" }
        if isLowPowerModeEnabled { return "low_power_mode" }
        
        switch batteryLevel {
        case 0.8...: return "high"
        case 0.5..<0.8: return "moderate"
        case 0.2..<0.5: return "low"
        default: return "critical"
        }
    }
}

// MARK: - Network Metrics

public struct NetworkMetrics: Codable {
    public let requestCount: Int
    public let totalBytesTransferred: Int64
    public let connectionFailures: Int
    public let averageLatency: TimeInterval
    public let connectionReliability: Double
    
    public func toDictionary() -> [String: Any] {
        return [
            "network_request_count": requestCount,
            "network_total_bytes_transferred": totalBytesTransferred,
            "network_connection_failures": connectionFailures,
            "network_average_latency": averageLatency,
            "network_connection_reliability": connectionReliability,
            "network_reliability_category": reliabilityCategory,
            "network_data_usage_category": dataUsageCategory
        ]
    }
    
    private var reliabilityCategory: String {
        switch connectionReliability {
        case 0.95...: return "excellent"
        case 0.8..<0.95: return "good"
        case 0.6..<0.8: return "fair"
        case 0.3..<0.6: return "poor"
        default: return "unreliable"
        }
    }
    
    private var dataUsageCategory: String {
        let megabytes = Double(totalBytesTransferred) / (1024 * 1024)
        switch megabytes {
        case 0..<1: return "minimal"
        case 1..<10: return "light"
        case 10..<100: return "moderate"
        case 100..<1000: return "heavy"
        default: return "excessive"
        }
    }
}

// MARK: - BGTaskScheduler Error Categorization

public struct BGTaskSchedulerErrorCategorizer {
    
    public struct ErrorCategorization {
        public let category: ErrorCategory
        public let severity: ErrorSeverity
        public let code: String
        public let isRetryable: Bool
        public let suggestedAction: String
    }
    
    public enum ErrorCategory: String, CaseIterable, Codable {
        case authorization = "authorization"
        case quota = "quota"
        case system = "system"
        case configuration = "configuration"
        case network = "network"
        case timeout = "timeout"
        case unavailable = "unavailable"
        case unknown = "unknown"
        
        public var displayName: String {
            switch self {
            case .authorization: return "Authorization Error"
            case .quota: return "Quota Exceeded"
            case .system: return "System Error"
            case .configuration: return "Configuration Error"
            case .network: return "Network Error"
            case .timeout: return "Timeout Error"
            case .unavailable: return "Service Unavailable"
            case .unknown: return "Unknown Error"
            }
        }
    }
    
    public enum ErrorSeverity: String, CaseIterable, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
        
        public var priority: Int {
            switch self {
            case .low: return 1
            case .medium: return 2
            case .high: return 3
            case .critical: return 4
            }
        }
    }
    
    public static func categorize(_ error: Error) -> ErrorCategorization {
        let nsError = error as NSError
        let domain = nsError.domain
        let code = nsError.code
        
        // Handle BackgroundTasks framework errors
        if domain == "BGTaskSchedulerErrorDomain" {
            return categorizeBGTaskError(code: code)
        }
        
        // Handle URL/Network errors
        if domain == NSURLErrorDomain {
            return categorizeNetworkError(code: code)
        }
        
        // Handle custom app errors
        if domain == "BackgroundTimeError" {
            return categorizeCustomError(code: code)
        }
        
        // Handle system errors
        if domain == NSCocoaErrorDomain || domain == NSPOSIXErrorDomain {
            return categorizeSystemError(code: code)
        }
        
        // Default categorization
        return ErrorCategorization(
            category: .unknown,
            severity: .medium,
            code: "\(domain):\(code)",
            isRetryable: false,
            suggestedAction: "Review error details and application logic"
        )
    }
    
    private static func categorizeBGTaskError(code: Int) -> ErrorCategorization {
        switch code {
        case 1: // BGTaskSchedulerErrorCodeUnavailable
            return ErrorCategorization(
                category: .unavailable,
                severity: .high,
                code: "BGTaskSchedulerErrorCodeUnavailable",
                isRetryable: true,
                suggestedAction: "Check Background App Refresh settings and device state"
            )
            
        case 2: // BGTaskSchedulerErrorCodeTooManyPendingTaskRequests
            return ErrorCategorization(
                category: .quota,
                severity: .medium,
                code: "BGTaskSchedulerErrorCodeTooManyPendingTaskRequests",
                isRetryable: false,
                suggestedAction: "Cancel existing pending tasks before scheduling new ones"
            )
            
        case 3: // BGTaskSchedulerErrorCodeNotPermitted
            return ErrorCategorization(
                category: .authorization,
                severity: .critical,
                code: "BGTaskSchedulerErrorCodeNotPermitted",
                isRetryable: false,
                suggestedAction: "Check Info.plist configuration and Background Modes capability"
            )
            
        default:
            return ErrorCategorization(
                category: .system,
                severity: .medium,
                code: "BGTaskSchedulerError:\(code)",
                isRetryable: true,
                suggestedAction: "Check BGTaskScheduler documentation for error code \(code)"
            )
        }
    }
    
    private static func categorizeNetworkError(code: Int) -> ErrorCategorization {
        switch code {
        case NSURLErrorTimedOut:
            return ErrorCategorization(
                category: .timeout,
                severity: .medium,
                code: "NSURLErrorTimedOut",
                isRetryable: true,
                suggestedAction: "Retry with exponential backoff"
            )
            
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            return ErrorCategorization(
                category: .network,
                severity: .high,
                code: "NSURLErrorNetworkUnavailable",
                isRetryable: true,
                suggestedAction: "Wait for network connectivity to be restored"
            )
            
        case NSURLErrorUserAuthenticationRequired, NSURLErrorUserCancelledAuthentication:
            return ErrorCategorization(
                category: .authorization,
                severity: .high,
                code: "NSURLErrorAuthentication",
                isRetryable: false,
                suggestedAction: "Update authentication credentials"
            )
            
        default:
            return ErrorCategorization(
                category: .network,
                severity: .medium,
                code: "NSURLError:\(code)",
                isRetryable: true,
                suggestedAction: "Check network configuration and retry"
            )
        }
    }
    
    private static func categorizeCustomError(code: Int) -> ErrorCategorization {
        switch code {
        case 1000: // TaskExpired
            return ErrorCategorization(
                category: .timeout,
                severity: .medium,
                code: "TaskExpired",
                isRetryable: true,
                suggestedAction: "Optimize task execution time or split into smaller tasks"
            )
            
        case 1001: // TaskCancelled
            return ErrorCategorization(
                category: .system,
                severity: .low,
                code: "TaskCancelled",
                isRetryable: false,
                suggestedAction: "Task was cancelled by system or user"
            )
            
        case 1002: // InsufficientResources
            return ErrorCategorization(
                category: .system,
                severity: .high,
                code: "InsufficientResources",
                isRetryable: true,
                suggestedAction: "Wait for better system conditions or reduce resource usage"
            )
            
        default:
            return ErrorCategorization(
                category: .unknown,
                severity: .medium,
                code: "CustomError:\(code)",
                isRetryable: false,
                suggestedAction: "Review application error handling"
            )
        }
    }
    
    private static func categorizeSystemError(code: Int) -> ErrorCategorization {
        // Common POSIX/Cocoa error codes
        switch code {
        case 1: // EPERM
            return ErrorCategorization(
                category: .authorization,
                severity: .high,
                code: "EPERM",
                isRetryable: false,
                suggestedAction: "Check permissions and entitlements"
            )
            
        case 2: // ENOENT
            return ErrorCategorization(
                category: .configuration,
                severity: .medium,
                code: "ENOENT",
                isRetryable: false,
                suggestedAction: "Check file paths and resource availability"
            )
            
        case 12: // ENOMEM
            return ErrorCategorization(
                category: .system,
                severity: .critical,
                code: "ENOMEM",
                isRetryable: true,
                suggestedAction: "Reduce memory usage and try again later"
            )
            
        case 13: // EACCES
            return ErrorCategorization(
                category: .authorization,
                severity: .high,
                code: "EACCES",
                isRetryable: false,
                suggestedAction: "Check file permissions and access rights"
            )
            
        default:
            return ErrorCategorization(
                category: .system,
                severity: .medium,
                code: "SystemError:\(code)",
                isRetryable: true,
                suggestedAction: "Check system resources and retry"
            )
        }
    }
}

// MARK: - Custom Error Types

public enum BackgroundTaskError: Error, LocalizedError, CustomStringConvertible {
    case taskExpired
    case taskCancelled
    case insufficientResources
    case configurationError(String)
    case networkError(String)
    case authorizationDenied
    
    public var errorDescription: String? {
        return description
    }
    
    public var description: String {
        switch self {
        case .taskExpired:
            return "Background task expired before completion"
        case .taskCancelled:
            return "Background task was cancelled"
        case .insufficientResources:
            return "Insufficient system resources to complete task"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .authorizationDenied:
            return "Authorization denied for background task scheduling"
        }
    }
    
    public var code: Int {
        switch self {
        case .taskExpired: return 1000
        case .taskCancelled: return 1001
        case .insufficientResources: return 1002
        case .configurationError: return 1003
        case .networkError: return 1004
        case .authorizationDenied: return 1005
        }
    }
}

// MARK: - Metric Aggregation Models

public struct MetricAggregationReport: Codable {
    public let timeRange: DateInterval
    public let taskMetrics: TaskMetricsSummary
    public let performanceMetrics: PerformanceMetricsSummary
    public let systemMetrics: SystemMetricsSummary
    public let networkMetrics: NetworkMetricsSummary
    public let errorMetrics: ErrorMetricsSummary
    public let generatedAt: Date
    
    public init(
        timeRange: DateInterval,
        taskMetrics: TaskMetricsSummary,
        performanceMetrics: PerformanceMetricsSummary,
        systemMetrics: SystemMetricsSummary,
        networkMetrics: NetworkMetricsSummary,
        errorMetrics: ErrorMetricsSummary
    ) {
        self.timeRange = timeRange
        self.taskMetrics = taskMetrics
        self.performanceMetrics = performanceMetrics
        self.systemMetrics = systemMetrics
        self.networkMetrics = networkMetrics
        self.errorMetrics = errorMetrics
        self.generatedAt = Date()
    }
}

public struct TaskMetricsSummary: Codable {
    public let totalTasksScheduled: Int
    public let totalTasksExecuted: Int
    public let totalTasksCompleted: Int
    public let totalTasksFailed: Int
    public let totalTasksExpired: Int
    public let averageExecutionDuration: TimeInterval
    public let averageSchedulingLatency: TimeInterval
    public let successRate: Double
    public let executionTimeDistribution: [String: Int] // Duration categories
    public let hourlyExecutionPattern: [Int: Int] // Hour -> Count
    
    public init(
        totalTasksScheduled: Int,
        totalTasksExecuted: Int,
        totalTasksCompleted: Int,
        totalTasksSuccessful: Int, // Add this parameter
        totalTasksFailed: Int,
        totalTasksExpired: Int,
        averageExecutionDuration: TimeInterval,
        averageSchedulingLatency: TimeInterval,
        executionTimeDistribution: [String: Int],
        hourlyExecutionPattern: [Int: Int]
    ) {
        self.totalTasksScheduled = totalTasksScheduled
        self.totalTasksExecuted = totalTasksExecuted
        self.totalTasksCompleted = totalTasksCompleted
        self.totalTasksFailed = totalTasksFailed
        self.totalTasksExpired = totalTasksExpired
        self.averageExecutionDuration = averageExecutionDuration
        self.averageSchedulingLatency = averageSchedulingLatency
        self.executionTimeDistribution = executionTimeDistribution
        self.hourlyExecutionPattern = hourlyExecutionPattern
        
        // Calculate success rate: successful completions / total executed attempts
        if totalTasksExecuted > 0 {
            self.successRate = Double(totalTasksSuccessful) / Double(totalTasksExecuted)
        } else {
            self.successRate = 0.0
        }
    }
}

public struct PerformanceMetricsSummary: Codable {
    public let averageCPUUsage: Double
    public let peakCPUUsage: Double
    public let averageMemoryUsage: Int64
    public let peakMemoryUsage: Int64
    public let energyImpactDistribution: [String: Int] // EnergyImpact -> Count
    public let averageEnergyImpactScore: Double
    public let highPerformanceTasksCount: Int
    public let lowPerformanceTasksCount: Int
}

public struct SystemMetricsSummary: Codable {
    public let averageBatteryLevel: Float
    public let lowPowerModeActivations: Int
    public let thermalStateDistribution: [String: Int]
    public let memoryPressureEvents: Int
    public let diskSpaceCriticalEvents: Int
    public let chargingTimePercentage: Double
    public let optimalConditionsPercentage: Double
}

public struct NetworkMetricsSummary: Codable {
    public let totalNetworkRequests: Int
    public let totalDataTransferred: Int64
    public let averageLatency: TimeInterval
    public let connectionFailureRate: Double
    public let reliabilityDistribution: [String: Int]
    public let dataUsageDistribution: [String: Int]
    public let networkUnavailableTime: TimeInterval
}

public struct ErrorMetricsSummary: Codable {
    public let totalErrors: Int
    public let errorCategoryDistribution: [String: Int]
    public let errorSeverityDistribution: [String: Int]
    public let retryableErrorsCount: Int
    public let criticalErrorsCount: Int
    public let mostCommonErrors: [String: Int] // Error code -> Count
    public let errorTrends: [String: [Date: Int]] // Category -> [Date: Count]
}

// MARK: - Extensions

// MARK: - Thermal State Wrapper (to avoid conformance conflicts)

public struct CodableThermalState: Codable {
    public let thermalState: ProcessInfo.ThermalState
    
    public init(_ thermalState: ProcessInfo.ThermalState) {
        self.thermalState = thermalState
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        
        switch rawValue {
        case 0: self.thermalState = .nominal
        case 1: self.thermalState = .fair
        case 2: self.thermalState = .serious
        case 3: self.thermalState = .critical
        default: self.thermalState = .nominal
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(thermalState.rawValue)
    }
}
