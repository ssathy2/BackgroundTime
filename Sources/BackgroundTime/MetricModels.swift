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

// MARK: - Debug Utilities

public struct BackgroundTaskEventDebugger {
    @MainActor
    public static func printAllEvents() {
        let events = BackgroundTime.shared.getAllEvents()
        print("🔍 Total Events: \(events.count)")
        
        for event in events.suffix(20) { // Show last 20 events
            print("📅 \(event.timestamp) - \(event.type.rawValue) - \(event.taskIdentifier) - Success: \(event.success)")
            if let duration = event.duration {
                print("   ⏱️ Duration: \(String(format: "%.3f", duration))s")
            }
        }
    }
    
    @MainActor
    public static func printEventsByType() {
        let events = BackgroundTime.shared.getAllEvents()
        let eventsByType = Dictionary(grouping: events) { $0.type }
        
        print("🔍 Events by Type:")
        for (type, events) in eventsByType {
            print("   \(type.rawValue): \(events.count)")
        }
    }
    
    @MainActor
    public static func printRecentTaskExecutions() {
        let events = BackgroundTime.shared.getAllEvents()
        let executionEvents = events.filter { 
            $0.type == .taskExecutionStarted || 
            $0.type == .taskExecutionCompleted || 
            $0.type == .taskExpired 
        }
        
        print("🚀 Recent Task Executions (last 10):")
        for event in executionEvents.suffix(10) {
            let durationStr = event.duration.map { String(format: "%.3f", $0) } ?? "N/A"
            print("   \(event.timestamp) - \(event.type.rawValue) - \(event.taskIdentifier) - Duration: \(durationStr)s")
        }
    }
    
    @MainActor
    public static func diagnoseAutomaticTracking() {
        let events = BackgroundTime.shared.getAllEvents()
        
        print("\n🔧 Automatic Tracking Diagnosis")
        print(String(repeating: "=", count: 40))
        
        // Check if swizzling is working
        let autoTrackedEvents = events.filter { 
            $0.metadata["auto_tracked"] == "true" && 
            $0.metadata["tracking_method"] == "swizzling"
        }
        
        print("📊 Tracking Statistics:")
        print("   Total events: \(events.count)")
        print("   Auto-tracked events: \(autoTrackedEvents.count)")
        print("   Manual events: \(events.count - autoTrackedEvents.count)")
        
        if autoTrackedEvents.isEmpty {
            print("\n❌ No auto-tracked events found!")
            print("💡 Possible issues:")
            print("   1. Swizzling may not be initialized")
            print("   2. App may not be calling BGTaskScheduler.register()")
            print("   3. Background tasks may not be completing via setTaskCompleted()")
        } else {
            print("\n✅ Automatic tracking is working!")
            print("   Recent auto-tracked events:")
            for event in autoTrackedEvents.suffix(5) {
                let timeStr = DateFormatter.shortTime.string(from: event.timestamp)
                print("   • \(timeStr) - \(event.type.rawValue) - \(event.taskIdentifier)")
            }
        }
        
        // Analyze task lifecycle completeness and success rate accuracy
        let taskGroups = Dictionary(grouping: events.filter { $0.taskIdentifier != "SDK_EVENT" }) { $0.taskIdentifier }
        
        print("\n📱 Task Lifecycle Analysis:")
        var totalExecuted = 0
        var totalSuccessful = 0
        var totalFailed = 0
        
        for (taskId, taskEvents) in taskGroups {
            let eventTypes = Set(taskEvents.map { $0.type })
            let hasStart = eventTypes.contains(.taskExecutionStarted)
            let hasCompletion = eventTypes.contains(.taskExecutionCompleted)
            let hasExpired = eventTypes.contains(.taskExpired)
            let hasFailed = eventTypes.contains(.taskFailed)
            let hasEnd = hasCompletion || hasExpired || hasFailed
            
            // Count execution attempts for this task
            let executionStartEvents = taskEvents.filter { $0.type == .taskExecutionStarted }
            let completionEvents = taskEvents.filter { $0.type == .taskExecutionCompleted }
            let successfulCompletions = completionEvents.filter { $0.success }.count
            let failedCompletions = completionEvents.filter { !$0.success }.count + taskEvents.filter { $0.type == .taskExpired }.count
            
            let taskExecuted = !executionStartEvents.isEmpty ? executionStartEvents.count : completionEvents.count
            totalExecuted += taskExecuted
            totalSuccessful += successfulCompletions
            totalFailed += failedCompletions
            
            let status = hasStart && hasEnd ? "✅" : hasStart ? "⚠️" : "❌"
            let successRateStr = taskExecuted > 0 ? String(format: "%.1f%%", Double(successfulCompletions) / Double(taskExecuted) * 100) : "N/A"
            print("   \(status) \(taskId): Start=\(hasStart ? "✓" : "✗"), End=\(hasEnd ? "✓" : "✗"), Success Rate=\(successRateStr)")
        }
        
        // Overall success rate analysis
        print("\n📈 Success Rate Analysis:")
        if totalExecuted > 0 {
            let overallSuccessRate = Double(totalSuccessful) / Double(totalExecuted) * 100
            print("   Overall Success Rate: \(String(format: "%.1f%%", overallSuccessRate)) (\(totalSuccessful)/\(totalExecuted))")
            print("   Total Executed: \(totalExecuted)")
            print("   Total Successful: \(totalSuccessful)")
            print("   Total Failed: \(totalFailed)")
            
            if overallSuccessRate < 70 {
                print("   ⚠️  Success rate is below 70% - consider investigating failures")
            } else if overallSuccessRate >= 90 {
                print("   ✅ Excellent success rate!")
            } else {
                print("   ℹ️  Good success rate")
            }
        } else {
            print("   No task executions recorded yet")
        }
        
        if taskGroups.values.contains(where: { taskEvents in
            let eventTypes = Set(taskEvents.map { $0.type })
            return !eventTypes.contains(.taskExecutionStarted)
        }) {
            print("\n🔧 Integration Help:")
            print("   Missing execution start events suggest the app needs to:")
            print("   1. Ensure BackgroundTime.initialize() is called")
            print("   2. Use BGTaskScheduler.shared.register() to register handlers")
            print("   3. Verify swizzling is working with BackgroundTime.isSwizzlingEnabled")
        }
    }
    
    @MainActor
    public static func printSwizzlingStatus() {
        let isSwizzlingEnabled = BackgroundTime.shared.isSwizzlingEnabled
        let isSDKInitialized = BackgroundTime.shared.isInitialized
        
        print("\n🔧 Method Swizzling Status")
        print(String(repeating: "=", count: 30))
        
        print("📊 Current Status:")
        print("   SDK Initialized: \(isSDKInitialized ? "✅" : "❌")")
        print("   Swizzling Enabled: \(isSwizzlingEnabled ? "✅" : "❌")")
        
        if !isSDKInitialized {
            print("\n⚠️  SDK not initialized!")
            print("   Add this to your app launch:")
            print("   BackgroundTime.shared.initialize()")
        }
        
        if !isSwizzlingEnabled {
            print("\n⚠️  Swizzling not enabled!")
            print("   Ensure initialize() completed successfully")
        }
        
        if isSwizzlingEnabled {
            print("\n✅ Swizzling is active!")
            print("   Your background tasks should be automatically tracked")
        }
        
        print("\n💡 Quick Test:")
        print("   1. Register a background task handler")
        print("   2. Simulate the task in debugger")
        print("   3. Call diagnoseAutomaticTracking()")
        print("   4. Look for 'auto_tracked' = true in events")
    }
    
    @MainActor
    public static func diagnoseLaunchHandlerIssue() {
        let events = BackgroundTime.shared.getAllEvents()
        
        print("\n🔍 Launch Handler Diagnosis")
        print(String(repeating: "=", count: 35))
        
        // Check for registration events
        let registrationEvents = events.filter { 
            $0.type == .taskScheduled && $0.metadata["registration_success"] == "true"
        }
        
        // Check for execution events
        let executionEvents = events.filter { 
            $0.type == .taskExecutionStarted
        }
        
        print("📊 Event Analysis:")
        print("   Total events: \(events.count)")
        print("   Registration events: \(registrationEvents.count)")
        print("   Execution start events: \(executionEvents.count)")
        
        if registrationEvents.isEmpty {
            print("\n❌ No registration events found!")
            print("💡 This suggests:")
            print("   1. BGTaskScheduler.register() hasn't been called yet")
            print("   2. Method swizzling may not be working")
            print("   3. Check if BackgroundTime.initialize() was called")
        } else {
            print("\n✅ Registration events found!")
            for event in registrationEvents.suffix(3) {
                let timeStr = DateFormatter.shortTime.string(from: event.timestamp)
                print("   • \(timeStr) - \(event.taskIdentifier)")
            }
        }
        
        if executionEvents.isEmpty && !registrationEvents.isEmpty {
            print("\n⚠️  Tasks registered but no executions detected!")
            print("💡 This suggests:")
            print("   1. Background tasks haven't been triggered by system yet")
            print("   2. wrappedLaunchHandler is not being called")
            print("   3. Try simulating background tasks in Xcode debugger")
            print("   4. Use 'e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@\"your.task.id\"]'")
        } else if !executionEvents.isEmpty {
            print("\n✅ Task executions detected!")
            for event in executionEvents.suffix(3) {
                let timeStr = DateFormatter.shortTime.string(from: event.timestamp)
                print("   • \(timeStr) - \(event.taskIdentifier)")
            }
        }
        
        // Check for completion tracking
        let completionEvents = events.filter { 
            $0.type == .taskExecutionCompleted || $0.type == .taskExpired
        }
        
        if !completionEvents.isEmpty {
            print("\n✅ Task completions tracked: \(completionEvents.count)")
        }
        
        // Look for specific metadata that indicates wrappedLaunchHandler is working
        let wrappedEvents = events.filter { 
            $0.metadata["auto_tracked"] == "true" && 
            $0.metadata["tracking_method"] == "swizzling" &&
            $0.type == .taskExecutionStarted
        }
        
        if wrappedEvents.isEmpty {
            print("\n❌ No auto-tracked execution events found!")
            print("💡 wrappedLaunchHandler is likely NOT being called")
            print("🔧 Debugging steps:")
            print("   1. Check console for '🚀 Task execution started for:' logs")
            print("   2. Check console for '🔗 Task registration intercepted for:' logs")
            print("   3. Verify method swizzling with printSwizzlingStatus()")
            print("   4. Try manual task simulation in debugger")
        } else {
            print("\n✅ Auto-tracked executions found: \(wrappedEvents.count)")
            print("   wrappedLaunchHandler appears to be working!")
        }
    }
}

// MARK: - Helper Extensions for Debugging

private extension DateFormatter {
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

// MARK: - Swizzling Verification Helpers

public struct BackgroundTimeSwizzlingHelper {
    
    /// Call this to verify that method swizzling is properly set up
    @MainActor
    public static func verifySwizzling() {
        print("\n🔍 Swizzling Verification Guide")
        print(String(repeating: "=", count: 35))
        
        print("1️⃣ Check initialization:")
        print("   BackgroundTime.initialize() should be called in app launch")
        
        print("\n2️⃣ Verify registration interception:")
        print("   When you call BGTaskScheduler.shared.register(), you should see:")
        print("   '🔗 Task registration intercepted for: [task_identifier]'")
        print("   '📋 Task registration result for [task_identifier]: true/false'")
        
        print("\n3️⃣ Verify launch handler wrapping:")
        print("   When background task is triggered, you should see:")
        print("   '🚀 Task execution started for: [task_identifier]'")
        print("   '📞 Calling original launch handler for: [task_identifier]'")
        print("   '✅ Original launch handler completed for: [task_identifier]'")
        
        print("\n4️⃣ Verify completion tracking:")
        print("   When task.setTaskCompleted() is called, you should see:")
        print("   '🎯 Task completion called for: [task_identifier], success: true/false'")
        
        print("\n5️⃣ Check events contain auto_tracked metadata:")
        print("   Call BackgroundTaskEventDebugger.diagnoseLaunchHandlerIssue()")
        
        print("\n📝 Example of working logs sequence:")
        print("   '🔗 Task registration intercepted for: com.app.refresh'")
        print("   '📋 Task registration result for com.app.refresh: true'")
        print("   '🚀 Task execution started for: com.app.refresh'")
        print("   '📞 Calling original launch handler for: com.app.refresh'")
        print("   '✅ Original launch handler completed for: com.app.refresh'")
        print("   '🎯 Task completion called for: com.app.refresh, success: true'")
    }
    
    /// Debug launch handler issue specifically
    @MainActor
    public static func debugLaunchHandlerIssue() {
        BackgroundTaskEventDebugger.diagnoseLaunchHandlerIssue()
    }
    
    /// Test the launch handler wrapping by registering a test task
    @MainActor
    public static func testLaunchHandlerWrapping() {
        let testTaskIdentifier = "test.launch.handler.wrapping.\(UUID().uuidString.prefix(8))"
        
        print("\n🧪 Testing Launch Handler Wrapping")
        print(String(repeating: "=", count: 35))
        
        print("📋 Registering test task: \(testTaskIdentifier)")
        
        let scheduler = BGTaskScheduler.shared
        let result = scheduler.register(forTaskWithIdentifier: testTaskIdentifier, using: nil) { task in
            print("🎯 Original launch handler called for: \(testTaskIdentifier)")
            
            // Simulate some work
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                print("✅ Completing test task: \(testTaskIdentifier)")
                task.setTaskCompleted(success: true)
            }
        }
        
        print("📋 Registration result: \(result)")
        
        if result {
            print("\n💡 To test the wrapped handler:")
            print("   1. Use Xcode debugger to simulate this task")
            print("   2. In debugger console, run:")
            print("   e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@\"\(testTaskIdentifier)\"]")
            print("   3. Watch for the launch handler logs above")
            print("   4. Call diagnoseLaunchHandlerIssue() to verify events were recorded")
        } else {
            print("\n❌ Registration failed - check your Info.plist BGTaskSchedulerPermittedIdentifiers")
        }
    }
    
    /// Verify success rate calculation accuracy
    @MainActor
    public static func verifySuccessRateCalculation() {
        let events = BackgroundTime.shared.getAllEvents()
        
        print("\n📊 Success Rate Calculation Verification")
        print(String(repeating: "=", count: 42))
        
        // Get current statistics
        let statistics = BackgroundTime.shared.getCurrentStats()
        
        print("🔢 Current Statistics:")
        print("   Total Executed: \(statistics.totalTasksExecuted)")
        print("   Total Completed: \(statistics.totalTasksCompleted)")
        print("   Total Failed: \(statistics.totalTasksFailed)")
        print("   Total Expired: \(statistics.totalTasksExpired)")
        print("   Success Rate: \(String(format: "%.1f%%", statistics.successRate * 100))")
        
        // Manual calculation verification
        let executionStartedEvents = events.filter { $0.type == .taskExecutionStarted }
        let completionEvents = events.filter { $0.type == .taskExecutionCompleted }
        let failedEvents = events.filter { $0.type == .taskFailed }
        let expiredEvents = events.filter { $0.type == .taskExpired }
        
        let manualTotalExecuted = !executionStartedEvents.isEmpty ? executionStartedEvents.count : completionEvents.count
        let manualSuccessfulCompletions = completionEvents.filter { $0.success }.count
        let manualSuccessRate = manualTotalExecuted > 0 ? Double(manualSuccessfulCompletions) / Double(manualTotalExecuted) : 0.0
        
        print("\n🧮 Manual Verification:")
        print("   Execution Started Events: \(executionStartedEvents.count)")
        print("   Completion Events: \(completionEvents.count)")
        print("   Successful Completions: \(manualSuccessfulCompletions)")
        print("   Failed Events: \(failedEvents.count)")
        print("   Expired Events: \(expiredEvents.count)")
        print("   Manual Success Rate: \(String(format: "%.1f%%", manualSuccessRate * 100))")
        
        // Compare calculations
        print("\n✅ Verification Results:")
        let executedMatch = statistics.totalTasksExecuted == manualTotalExecuted
        let successRateMatch = abs(statistics.successRate - manualSuccessRate) < 0.001
        
        print("   Executed Count Match: \(executedMatch ? "✅" : "❌") (\(statistics.totalTasksExecuted) vs \(manualTotalExecuted))")
        print("   Success Rate Match: \(successRateMatch ? "✅" : "❌") (\(String(format: "%.3f", statistics.successRate)) vs \(String(format: "%.3f", manualSuccessRate)))")
        
        if !executedMatch || !successRateMatch {
            print("\n⚠️  Success rate calculation discrepancy detected!")
            print("💡 This may indicate:")
            print("   1. Event tracking inconsistencies")
            print("   2. Calculation logic differences")
            print("   3. Missing or duplicate events")
        } else {
            print("\n✅ Success rate calculations are accurate!")
        }
        
        // Task-by-task breakdown
        let taskGroups = Dictionary(grouping: events.filter { $0.taskIdentifier != "SDK_EVENT" }) { $0.taskIdentifier }
        
        if !taskGroups.isEmpty {
            print("\n📋 Per-Task Success Rates:")
            for (taskId, taskEvents) in taskGroups.sorted(by: { $0.key < $1.key }) {
                let taskStartEvents = taskEvents.filter { $0.type == .taskExecutionStarted }
                let taskCompletionEvents = taskEvents.filter { $0.type == .taskExecutionCompleted }
                let taskExecutedCount = !taskStartEvents.isEmpty ? taskStartEvents.count : taskCompletionEvents.count
                let taskSuccessfulCount = taskCompletionEvents.filter { $0.success }.count
                let taskSuccessRate = taskExecutedCount > 0 ? Double(taskSuccessfulCount) / Double(taskExecutedCount) : 0.0
                
                print("   \(taskId): \(String(format: "%.1f%%", taskSuccessRate * 100)) (\(taskSuccessfulCount)/\(taskExecutedCount))")
            }
        }
    }
}
