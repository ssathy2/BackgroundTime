//
//  BackgroundTimeModels.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Foundation
import UIKit

// MARK: - Event Types

public enum BackgroundTaskEventType: String, Codable, CaseIterable, Sendable {
    case taskScheduled = "task_scheduled"
    case taskExecutionStarted = "task_execution_started"
    case taskExecutionCompleted = "task_execution_completed"
    case taskExpired = "task_expired"
    case taskCancelled = "task_cancelled"
    case taskFailed = "task_failed"
    case initialization = "sdk_initialization"
    case appEnteredBackground = "app_entered_background"
    case appWillEnterForeground = "app_will_enter_foreground"
    // Continuous Background Tasks (iOS 26.0+)
    case continuousTaskStarted = "continuous_task_started"
    case continuousTaskPaused = "continuous_task_paused"
    case continuousTaskResumed = "continuous_task_resumed"
    case continuousTaskStopped = "continuous_task_stopped"
    case continuousTaskProgress = "continuous_task_progress"
    
    /// Returns true if this event type is related to continuous background tasks (iOS 26.0+)
    public var isContinuousTaskEvent: Bool {
        if #available(iOS 26.0, *) {
            switch self {
            case .continuousTaskStarted, .continuousTaskPaused, .continuousTaskResumed, 
                 .continuousTaskStopped, .continuousTaskProgress:
                return true
            default:
                return false
            }
        }
        return false
    }
    
    /// Returns true if this event type should be included in task statistics calculations
    public var isTaskStatisticsEvent: Bool {
        switch self {
        case .taskScheduled, .taskExecutionStarted, .taskExecutionCompleted,
             .taskExpired, .taskCancelled, .taskFailed,
             .continuousTaskStarted, .continuousTaskPaused, .continuousTaskResumed,
             .continuousTaskStopped, .continuousTaskProgress:
            return true
        case .initialization, .appEnteredBackground, .appWillEnterForeground:
            return false
        }
    }
}

// MARK: - Background Task Event

public struct BackgroundTaskEvent: Codable, Identifiable, Sendable {
    public let id: UUID
    public let taskIdentifier: String
    public let type: BackgroundTaskEventType
    public let timestamp: Date
    public let duration: TimeInterval?
    public let success: Bool
    public let errorMessage: String?
    public let metadata: [String: String]
    public let systemInfo: SystemInfo
    
    public init(
        id: UUID,
        taskIdentifier: String,
        type: BackgroundTaskEventType,
        timestamp: Date,
        duration: TimeInterval? = nil,
        success: Bool,
        errorMessage: String? = nil,
        metadata: [String: String] = [:],
        systemInfo: SystemInfo
    ) {
        self.id = id
        self.taskIdentifier = taskIdentifier
        self.type = type
        self.timestamp = timestamp
        self.duration = duration
        self.success = success
        self.errorMessage = errorMessage
        self.metadata = metadata
        self.systemInfo = systemInfo
    }
    
    enum CodingKeys: String, CodingKey {
        case id, taskIdentifier, type, timestamp, duration, success, errorMessage, systemInfo
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        taskIdentifier = try container.decode(String.self, forKey: .taskIdentifier)
        type = try container.decode(BackgroundTaskEventType.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        success = try container.decode(Bool.self, forKey: .success)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        systemInfo = try container.decode(SystemInfo.self, forKey: .systemInfo)
        metadata = [:] // Simplified for Codable compliance
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(taskIdentifier, forKey: .taskIdentifier)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encode(systemInfo, forKey: .systemInfo)
    }
}

// MARK: - System Information

public struct SystemInfo: Codable, Sendable {
    public let backgroundAppRefreshStatus: UIBackgroundRefreshStatus
    public let deviceModel: String
    public let systemVersion: String
    public let lowPowerModeEnabled: Bool
    public let batteryLevel: Float
    public let batteryState: UIDevice.BatteryState
    
    enum CodingKeys: String, CodingKey {
        case backgroundAppRefreshStatus, deviceModel, systemVersion, lowPowerModeEnabled, batteryLevel, batteryState
    }
    
    public init(
        backgroundAppRefreshStatus: UIBackgroundRefreshStatus,
        deviceModel: String,
        systemVersion: String,
        lowPowerModeEnabled: Bool,
        batteryLevel: Float,
        batteryState: UIDevice.BatteryState
    ) {
        self.backgroundAppRefreshStatus = backgroundAppRefreshStatus
        self.deviceModel = deviceModel
        self.systemVersion = systemVersion
        self.lowPowerModeEnabled = lowPowerModeEnabled
        self.batteryLevel = batteryLevel
        self.batteryState = batteryState
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(backgroundAppRefreshStatus.rawValue, forKey: .backgroundAppRefreshStatus)
        try container.encode(deviceModel, forKey: .deviceModel)
        try container.encode(systemVersion, forKey: .systemVersion)
        try container.encode(lowPowerModeEnabled, forKey: .lowPowerModeEnabled)
        try container.encode(batteryLevel, forKey: .batteryLevel)
        try container.encode(batteryState.rawValue, forKey: .batteryState)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let refreshStatusRaw = try container.decode(Int.self, forKey: .backgroundAppRefreshStatus)
        backgroundAppRefreshStatus = UIBackgroundRefreshStatus(rawValue: refreshStatusRaw) ?? .restricted
        deviceModel = try container.decode(String.self, forKey: .deviceModel)
        systemVersion = try container.decode(String.self, forKey: .systemVersion)
        lowPowerModeEnabled = try container.decode(Bool.self, forKey: .lowPowerModeEnabled)
        batteryLevel = try container.decode(Float.self, forKey: .batteryLevel)
        let batteryStateRaw = try container.decode(Int.self, forKey: .batteryState)
        batteryState = UIDevice.BatteryState(rawValue: batteryStateRaw) ?? .unknown
    }
}

// MARK: - Statistics and Dashboard Models

public struct BackgroundTaskStatistics: Codable, Sendable {
    public let totalTasksScheduled: Int
    public let totalTasksExecuted: Int
    public let totalTasksCompleted: Int
    public let totalTasksFailed: Int
    public let totalTasksExpired: Int
    public let averageExecutionTime: TimeInterval
    public let successRate: Double
    public let executionsByHour: [Int: Int] // Hour -> Count
    public let errorsByType: [String: Int]
    public let lastExecutionTime: Date?
    public let generatedAt: Date
}

public struct TimelineDataPoint: Codable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let eventType: BackgroundTaskEventType
    public let taskIdentifier: String
    public let duration: TimeInterval?
    public let success: Bool
    
    public init(
        id: UUID = UUID(),
        timestamp: Date,
        eventType: BackgroundTaskEventType,
        taskIdentifier: String,
        duration: TimeInterval?,
        success: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.taskIdentifier = taskIdentifier
        self.duration = duration
        self.success = success
    }
}

public struct BackgroundTaskDashboardData: Codable, Sendable {
    public let statistics: BackgroundTaskStatistics
    public let events: [BackgroundTaskEvent]
    public let timeline: [TimelineDataPoint]
    public let systemInfo: SystemInfo
    public let generatedAt: Date
    
    public init(
        statistics: BackgroundTaskStatistics,
        events: [BackgroundTaskEvent],
        timeline: [TimelineDataPoint],
        systemInfo: SystemInfo,
        generatedAt: Date = Date()
    ) {
        self.statistics = statistics
        self.events = events
        self.timeline = timeline
        self.systemInfo = systemInfo
        self.generatedAt = generatedAt
    }
}

// MARK: - Continuous Background Tasks (iOS 26.0+)

@available(iOS 26.0, *)
public struct ContinuousTaskInfo: Codable, Identifiable {
    public let id: UUID
    public let taskIdentifier: String
    public let startTime: Date
    public let currentStatus: ContinuousTaskStatus
    public let totalRunTime: TimeInterval
    public let pausedTime: TimeInterval
    public let resumeCount: Int
    public let progressUpdates: [ContinuousTaskProgress]
    public let expectedDuration: TimeInterval?
    public let priority: TaskPriority
    
    public init(
        id: UUID = UUID(),
        taskIdentifier: String,
        startTime: Date,
        currentStatus: ContinuousTaskStatus,
        totalRunTime: TimeInterval = 0,
        pausedTime: TimeInterval = 0,
        resumeCount: Int = 0,
        progressUpdates: [ContinuousTaskProgress] = [],
        expectedDuration: TimeInterval? = nil,
        priority: TaskPriority = .medium
    ) {
        self.id = id
        self.taskIdentifier = taskIdentifier
        self.startTime = startTime
        self.currentStatus = currentStatus
        self.totalRunTime = totalRunTime
        self.pausedTime = pausedTime
        self.resumeCount = resumeCount
        self.progressUpdates = progressUpdates
        self.expectedDuration = expectedDuration
        self.priority = priority
    }
}

@available(iOS 26.0, *)
public enum ContinuousTaskStatus: String, Codable, CaseIterable {
    case running = "running"
    case paused = "paused" 
    case completed = "completed"
    case stopped = "stopped"
    case failed = "failed"
    
    public var displayName: String {
        switch self {
        case .running: return "Running"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .stopped: return "Stopped"
        case .failed: return "Failed"
        }
    }
    
    public var isActive: Bool {
        return self == .running || self == .paused
    }
}

@available(iOS 26.0, *)
public struct ContinuousTaskProgress: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let completedUnitCount: Int64
    public let totalUnitCount: Int64
    public let localizedDescription: String?
    public let userInfo: [String: String]
    
    public var fractionCompleted: Double {
        guard totalUnitCount > 0 else { return 0 }
        return Double(completedUnitCount) / Double(totalUnitCount)
    }
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        completedUnitCount: Int64,
        totalUnitCount: Int64,
        localizedDescription: String? = nil,
        userInfo: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.completedUnitCount = completedUnitCount
        self.totalUnitCount = totalUnitCount
        self.localizedDescription = localizedDescription
        self.userInfo = userInfo
    }
}

@available(iOS 26.0, *)
public enum TaskPriority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case userInitiated = "user_initiated"
    
    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .userInitiated: return "User Initiated"
        }
    }
}

// MARK: - Time Range for filtering
public enum TimeRange: Codable, CaseIterable {
    case last1Hour
    case last6Hours 
    case last24Hours
    case last7Days
    case last30Days
    case all
    
    public var timeInterval: TimeInterval {
        switch self {
        case .last1Hour: return 3600 // 1 hour
        case .last6Hours: return 6 * 3600 // 6 hours
        case .last24Hours: return 24 * 3600 // 24 hours 
        case .last7Days: return 7 * 24 * 3600 // 7 days
        case .last30Days: return 30 * 24 * 3600 // 30 days
        case .all: return TimeInterval.greatestFiniteMagnitude
        }
    }
    
    public var displayName: String {
        switch self {
        case .last1Hour: return "Last Hour"
        case .last6Hours: return "Last 6 Hours"
        case .last24Hours: return "Last 24 Hours"
        case .last7Days: return "Last 7 Days" 
        case .last30Days: return "Last 30 Days"
        case .all: return "All Time"
        }
    }
    
    /// Short display name for use in segmented controls with limited space
    public var shortDisplayName: String {
        switch self {
        case .last1Hour: return "1H"
        case .last6Hours: return "6H"
        case .last24Hours: return "24H"
        case .last7Days: return "7D" 
        case .last30Days: return "30D"
        case .all: return "All"
        }
    }
}
