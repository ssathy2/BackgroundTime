//
//  DashboardTypes.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import SwiftUI
import Charts

// MARK: - Dashboard Tab Types

public enum DashboardTab: CaseIterable {
    case overview, timeline, performance, errors, analysis, continuousTasks
    
    public var title: String {
        switch self {
        case .overview: return "Overview"
        case .timeline: return "Timeline"
        case .performance: return "Performance"
        case .errors: return "Errors"
        case .analysis: return "Analysis"
        case .continuousTasks: return "Continuous"
        }
    }
    
    public var systemImage: String {
        switch self {
        case .overview: return "chart.bar.fill"
        case .timeline: return "clock.fill"
        case .performance: return "speedometer"
        case .errors: return "exclamationmark.triangle.fill"
        case .analysis: return "lightbulb.fill"
        case .continuousTasks: return "infinity.circle.fill"
        }
    }
    
    @available(iOS 26.0, *)
    public static var allCasesForCurrentOS: [DashboardTab] {
        return DashboardTab.allCases
    }
    
    public static var allCasesForLegacyOS: [DashboardTab] {
        return [.overview, .timeline, .performance, .errors, .analysis]
    }
}

// MARK: - Performance Types

public enum PerformanceMetricFilter: CaseIterable {
    case all, slow, failed, recent
    
    public var displayName: String {
        switch self {
        case .all: return "All Tasks"
        case .slow: return "Slow Tasks"
        case .failed: return "Failed Tasks"
        case .recent: return "Recent"
        }
    }
    
    public var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .slow: return "tortoise.fill"
        case .failed: return "xmark.circle.fill"
        case .recent: return "clock.fill"
        }
    }
}

public enum PerformanceTrend {
    case improving, stable, declining
    
    public var color: Color {
        switch self {
        case .improving: return .green
        case .stable: return .blue
        case .declining: return .red
        }
    }
    
    public var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }
}

public struct DurationEvent: Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let duration: TimeInterval
    public let taskIdentifier: String
    
    public init(id: UUID, timestamp: Date, duration: TimeInterval, taskIdentifier: String) {
        self.id = id
        self.timestamp = timestamp
        self.duration = duration
        self.taskIdentifier = taskIdentifier
    }
}

public enum PerformanceInsightType {
    case optimization, warning, info
    
    public var color: Color {
        switch self {
        case .optimization: return .blue
        case .warning: return .orange
        case .info: return .purple
        }
    }
    
    public var icon: String {
        switch self {
        case .optimization: return "lightbulb.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

public enum PerformancePriority {
    case low, medium, high, critical
    
    public var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

public struct PerformanceInsight: Identifiable {
    public let id: UUID
    public let type: PerformanceInsightType
    public let title: String
    public let description: String
    public let priority: PerformancePriority
    public let actionable: Bool
    
    public init(id: UUID, type: PerformanceInsightType, title: String, description: String, priority: PerformancePriority, actionable: Bool) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.priority = priority
        self.actionable = actionable
    }
}

// MARK: - Continuous Tasks Types (iOS 26.0+)

@available(iOS 26.0, *)
public enum ContinuousTaskDisplayStatus {
    case running, paused, stopped, unknown
    
    public var displayName: String {
        switch self {
        case .running: return "Running"
        case .paused: return "Paused"
        case .stopped: return "Stopped"
        case .unknown: return "Unknown"
        }
    }
    
    public var color: Color {
        switch self {
        case .running: return .green
        case .paused: return .yellow
        case .stopped: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - iOS Version Support Helpers

extension UIDevice {
    /// Returns true if the current device supports Continuous Background Tasks (iOS 26.0+)
    public static var supportsContinuousBackgroundTasks: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }
}

// MARK: - Extensions

extension BackgroundTaskEventType {
    public var icon: String {
        switch self {
        case .taskScheduled:
            return "calendar.badge.plus"
        case .taskExecutionStarted:
            return "play.fill"
        case .taskExecutionCompleted:
            return "checkmark.circle.fill"
        case .taskExpired:
            return "clock.badge.exclamationmark"
        case .taskCancelled:
            return "xmark.circle.fill"
        case .taskFailed:
            return "exclamationmark.triangle.fill"
        case .metricKitDataReceived:
            return "gear"
        case .appEnteredBackground:
            return "moon.fill"
        case .appWillEnterForeground:
            return "sun.max.fill"
        case .continuousTaskStarted:
            if #available(iOS 26.0, *) {
                return "infinity.circle.fill"
            } else {
                return "play.fill"
            }
        case .continuousTaskPaused:
            if #available(iOS 26.0, *) {
                return "pause.circle.fill"
            } else {
                return "pause.fill"
            }
        case .continuousTaskResumed:
            if #available(iOS 26.0, *) {
                return "play.circle.fill"
            } else {
                return "play.fill"
            }
        case .continuousTaskStopped:
            if #available(iOS 26.0, *) {
                return "stop.circle.fill"
            } else {
                return "stop.fill"
            }
        case .continuousTaskProgress:
            if #available(iOS 26.0, *) {
                return "chart.line.uptrend.xyaxis"
            } else {
                return "chart.bar.fill"
            }
        }
    }
}

// MARK: - Time Range Extensions

extension TimeRange {
    public var startDate: Date {
        let endDate = Date()
        if self == .all {
            return Date(timeIntervalSince1970: 0) // Include all events
        } else {
            return endDate.addingTimeInterval(-timeInterval)
        }
    }
    
    public var endDate: Date {
        return Date()
    }
    
    public func contains(_ date: Date) -> Bool {
        return date >= startDate && date <= endDate
    }
    
    /// Create a DateInterval for this time range
    public var dateInterval: DateInterval {
        return DateInterval(start: startDate, end: endDate)
    }
    
    /// Debug description for logging
    public var debugDescription: String {
        return "\(displayName): \(startDate) to \(endDate) (\(timeInterval)s)"
    }
}

// MARK: - Helper Functions

public func formatTimeInterval(_ interval: TimeInterval) -> String {
    if interval < 60 {
        return String(format: "%.1fs", interval)
    } else if interval < 3600 {
        return String(format: "%.1fm", interval / 60)
    } else {
        return String(format: "%.1fh", interval / 3600)
    }
}