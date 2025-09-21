//
//  BackgroundTimeModels.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Foundation
import UIKit

// MARK: - Event Types

public enum BackgroundTaskEventType: String, Codable, CaseIterable {
    case taskScheduled = "task_scheduled"
    case taskExecutionStarted = "task_execution_started"
    case taskExecutionCompleted = "task_execution_completed"
    case taskExpired = "task_expired"
    case taskCancelled = "task_cancelled"
    case taskFailed = "task_failed"
    case initialization = "sdk_initialization"
    case appEnteredBackground = "app_entered_background"
    case appWillEnterForeground = "app_will_enter_foreground"
}

// MARK: - Background Task Event

public struct BackgroundTaskEvent: Codable, Identifiable {
    public let id: UUID
    public let taskIdentifier: String
    public let type: BackgroundTaskEventType
    public let timestamp: Date
    public let duration: TimeInterval?
    public let success: Bool
    public let errorMessage: String?
    public let metadata: [String: Any]
    public let systemInfo: SystemInfo
    
    public init(
        id: UUID,
        taskIdentifier: String,
        type: BackgroundTaskEventType,
        timestamp: Date,
        duration: TimeInterval? = nil,
        success: Bool,
        errorMessage: String? = nil,
        metadata: [String: Any] = [:],
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

public struct SystemInfo: Codable {
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

public struct BackgroundTaskStatistics: Codable {
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

public struct TimelineDataPoint: Codable, Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let eventType: BackgroundTaskEventType
    public let taskIdentifier: String
    public let duration: TimeInterval?
    public let success: Bool
}

public struct BackgroundTaskDashboardData: Codable {
    public let statistics: BackgroundTaskStatistics
    public let events: [BackgroundTaskEvent]
    public let timeline: [TimelineDataPoint]
    public let systemInfo: SystemInfo
    public let generatedAt: Date = Date()
}
