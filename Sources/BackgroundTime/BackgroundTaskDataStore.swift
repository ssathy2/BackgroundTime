//
//  BackgroundTaskDataStore.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Foundation
import os.log

// MARK: - Data Storage Manager

final class BackgroundTaskDataStore: @unchecked Sendable {
    static let shared = BackgroundTaskDataStore()
    
    private let logger = Logger(subsystem: "BackgroundTime", category: "DataStore")
    private let eventStore: ThreadSafeDataStore<BackgroundTaskEvent>
    private let performanceMonitor = AccessPatternMonitor.shared
    
    private let userDefaults: UserDefaults
    private let eventsKey = "BackgroundTime.StoredEvents"
    private let isTestEnvironment: Bool
    
    private init() {
        // Detect test environment
        self.isTestEnvironment = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                                NSClassFromString("XCTestCase") != nil ||
                                ProcessInfo.processInfo.arguments.contains("--test")
        
        // Initialize with default capacity and default UserDefaults suite
        self.eventStore = ThreadSafeDataStore<BackgroundTaskEvent>(capacity: 1000)
        self.userDefaults = UserDefaults(suiteName: "BackgroundTime.DataStore") ?? UserDefaults.standard
        loadPersistedEvents()
    }
    
    /// Create a data store instance with custom UserDefaults for testing
    init(userDefaults: UserDefaults) {
        // Test environment detection for custom instances (likely used in tests)
        self.isTestEnvironment = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                                NSClassFromString("XCTestCase") != nil ||
                                ProcessInfo.processInfo.arguments.contains("--test")
        
        self.eventStore = ThreadSafeDataStore<BackgroundTaskEvent>(capacity: 1000)
        self.userDefaults = userDefaults
        loadPersistedEvents()
    }
    
    // MARK: - Helper Methods
    
    /// Log messages only when not in test environment
    private func logInfo(_ message: String) {
        guard !isTestEnvironment else { return }
        logger.info("\(message)")
    }
    
    private func logWarning(_ message: String) {
        guard !isTestEnvironment else { return }
        logger.warning("\(message)")
    }
    
    private func logError(_ message: String) {
        guard !isTestEnvironment else { return }
        logger.error("\(message)")
    }
    
    func configure(maxStoredEvents: Int) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        eventStore.resize(to: maxStoredEvents)
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        performanceMonitor.recordAccess(operation: "configure", duration: duration)
        
        logInfo("Configured data store with max events: \(maxStoredEvents)")
    }
    
    func recordEvent(_ event: BackgroundTaskEvent) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let droppedEvent = eventStore.append(event)
        persistEvents()
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        performanceMonitor.recordAccess(operation: "recordEvent", duration: duration)
        
        if droppedEvent != nil {
            logWarning("Event dropped due to capacity limit: \(droppedEvent!.taskIdentifier)")
        }
        
        logInfo("Recorded event: \(event.type.rawValue) for task: \(event.taskIdentifier)")
    }
    
    func getAllEvents() -> [BackgroundTaskEvent] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let events = eventStore.toArray()
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        performanceMonitor.recordAccess(operation: "getAllEvents", duration: duration)
        
        return events
    }
    
    func getEvents(for taskIdentifier: String) -> [BackgroundTaskEvent] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let events = eventStore.filter { $0.taskIdentifier == taskIdentifier }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        performanceMonitor.recordAccess(operation: "getEventsForTask", duration: duration)
        
        return events
    }
    
    func getEventsInDateRange(from startDate: Date, to endDate: Date) -> [BackgroundTaskEvent] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let events = eventStore.filter { event in
            event.timestamp >= startDate && event.timestamp <= endDate
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        performanceMonitor.recordAccess(operation: "getEventsInDateRange", duration: duration)
        
        return events
    }
    
    func generateStatistics() -> BackgroundTaskStatistics {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let statistics = eventStore.performBatchRead { events in
            return generateStatisticsInternal(from: events)
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        performanceMonitor.recordAccess(operation: "generateStatistics", duration: duration)
        
        return statistics
    }
    
    func generateStatistics(for events: [BackgroundTaskEvent], in dateRange: ClosedRange<Date>) -> BackgroundTaskStatistics {
        return generateStatisticsInternal(from: events)
    }
    
    private func generateStatisticsInternal(from events: [BackgroundTaskEvent]) -> BackgroundTaskStatistics {
        // Filter to only include events that should be counted in statistics
        let statisticsEvents = events.filter { $0.type.isTaskStatisticsEvent }
        
        let totalScheduled = statisticsEvents.filter { $0.type == .taskScheduled }.count
        
        // Count distinct task execution attempts by tracking unique task identifiers that started execution
        let executionStartedEvents = statisticsEvents.filter { $0.type == .taskExecutionStarted }
        let completionEvents = statisticsEvents.filter { $0.type == .taskExecutionCompleted }
        let failedEvents = statisticsEvents.filter { $0.type == .taskFailed }
        let expiredEvents = statisticsEvents.filter { $0.type == .taskExpired }
        let cancelledEvents = statisticsEvents.filter { $0.type == .taskCancelled }
        
        // Primary approach: Use execution started events if available
        let totalExecuted = !executionStartedEvents.isEmpty ? executionStartedEvents.count : completionEvents.count
        
        // Count successful completions (tasks that completed successfully)
        let successfulCompletions = completionEvents.filter { $0.success }.count
        
        // Count failed completions (tasks that completed but were marked as unsuccessful)
        let failedCompletions = completionEvents.filter { !$0.success }.count
        
        let totalExpired = expiredEvents.count
        
        // Total completed should count ONLY successful completions
        // Based on test expectations, "completed" means "successfully completed"
        let totalCompleted = successfulCompletions
        
        // Total failed includes failed completions, explicit failures, expired tasks, and cancelled tasks
        let totalFailed = failedCompletions + failedEvents.count + totalExpired + cancelledEvents.count
        
        // Calculate average execution time from completed events (successful or failed) with duration
        let eventsWithDuration = completionEvents.filter { $0.duration != nil }
        let averageExecutionTime = eventsWithDuration.isEmpty ? 0 : 
            eventsWithDuration.compactMap { $0.duration }.reduce(0, +) / Double(eventsWithDuration.count)
        
        // Success rate calculation: successful completions / total executed attempts
        // If we have no execution attempts recorded, success rate is 0
        let successRate: Double
        if totalExecuted > 0 {
            let rate = Double(successfulCompletions) / Double(totalExecuted)
            // Ensure success rate is always between 0.0 and 1.0 (defensive programming)
            successRate = min(max(rate, 0.0), 1.0)
            
            // Debug logging for unusual success rates
            if rate > 1.0 {
                logWarning("⚠️ Success rate calculation anomaly detected:")
                logWarning("  - Total executed: \(totalExecuted)")
                logWarning("  - Successful completions: \(successfulCompletions)")
                logWarning("  - Raw success rate: \(rate) (\(rate * 100)%)")
                logWarning("  - Clamped to: \(successRate) (\(successRate * 100)%)")
                logWarning("  - Execution started events: \(executionStartedEvents.count)")
                logWarning("  - Completion events: \(completionEvents.count)")
            }
        } else {
            successRate = 0.0
        }
        
        // Group executions by hour (prefer execution started events, fallback to completion events)
        let executionsByHour = Dictionary(grouping: !executionStartedEvents.isEmpty ? executionStartedEvents : completionEvents) { event in
            Calendar.current.component(.hour, from: event.timestamp)
        }.mapValues { $0.count }
        
        // Group errors by type from failed, expired, cancelled events and unsuccessful completion events
        let errorEvents = statisticsEvents.filter { 
            $0.type == .taskFailed || 
            ($0.type == .taskExecutionCompleted && !$0.success) ||
            $0.type == .taskExpired ||
            $0.type == .taskCancelled
        }
        let errorsByType = Dictionary(grouping: errorEvents) { event in
            event.errorMessage?.isEmpty == false ? event.errorMessage! : "Unknown Error"
        }.mapValues { $0.count }
        
        // Last execution time from started events or completion events
        let lastExecutionTime = (!executionStartedEvents.isEmpty ? executionStartedEvents : completionEvents)
            .max(by: { $0.timestamp < $1.timestamp })?.timestamp
        
        return BackgroundTaskStatistics(
            totalTasksScheduled: totalScheduled,
            totalTasksExecuted: totalExecuted,
            totalTasksCompleted: totalCompleted,
            totalTasksFailed: totalFailed,
            totalTasksExpired: totalExpired,
            averageExecutionTime: averageExecutionTime,
            successRate: successRate,
            executionsByHour: executionsByHour,
            errorsByType: errorsByType,
            lastExecutionTime: lastExecutionTime,
            generatedAt: Date()
        )
    }
    
    func clearAllEvents() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        eventStore.clear()
        persistEvents()
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        performanceMonitor.recordAccess(operation: "clearAllEvents", duration: duration)
        
        logInfo("Cleared all stored events")
    }
    
    // MARK: - Private Methods
    
    private func persistEvents() {
        do {
            let events = eventStore.toArray()
            let data = try JSONEncoder().encode(events)
            userDefaults.set(data, forKey: eventsKey)
        } catch {
            logError("Failed to persist events: \(error.localizedDescription)")
        }
    }
    
    private func loadPersistedEvents() {
        guard let data = userDefaults.data(forKey: eventsKey) else { return }
        
        do {
            let events = try JSONDecoder().decode([BackgroundTaskEvent].self, from: data)
            eventStore.append(contentsOf: events)
            logInfo("Loaded \(events.count) persisted events")
        } catch {
            logError("Failed to load persisted events: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Performance Monitoring
    
    func getDataStorePerformance() -> PerformanceReport {
        return performanceMonitor.getPerformanceReport()
    }
    
    func getBufferStatistics() -> BufferStatistics {
        return eventStore.getStatistics()
    }
}

// MARK: - Analytics Helper

extension BackgroundTaskDataStore {
    func getTaskPerformanceMetrics(for taskIdentifier: String) -> TaskPerformanceMetrics? {
        let taskEvents = getEvents(for: taskIdentifier)
        return generateTaskMetrics(for: taskIdentifier, from: taskEvents)
    }
    
    func getTaskPerformanceMetrics(for taskIdentifier: String, in dateRange: ClosedRange<Date>) -> TaskPerformanceMetrics? {
        let taskEvents = getEvents(for: taskIdentifier).filter { dateRange.contains($0.timestamp) }
        return generateTaskMetrics(for: taskIdentifier, from: taskEvents)
    }
    
    func generateTaskMetrics(for taskIdentifier: String, from taskEvents: [BackgroundTaskEvent]) -> TaskPerformanceMetrics? {
        // Filter to only include events that should be counted in task statistics
        let statisticsEvents = taskEvents.filter { $0.type.isTaskStatisticsEvent }
        guard !statisticsEvents.isEmpty else { return nil }
        
        let scheduledEvents = statisticsEvents.filter { $0.type == .taskScheduled }
        let executedEvents = statisticsEvents.filter { $0.type == .taskExecutionStarted }
        let completedEvents = statisticsEvents.filter { $0.type == .taskExecutionCompleted }
        let failedEvents = statisticsEvents.filter { $0.type == .taskFailed }
        let expiredEvents = statisticsEvents.filter { $0.type == .taskExpired }
        let cancelledEvents = statisticsEvents.filter { $0.type == .taskCancelled }
        
        // Use execution started events if available, otherwise infer from completion events
        let totalExecuted = !executedEvents.isEmpty ? executedEvents.count : completedEvents.count
        
        // Count successful completions (tasks that completed successfully)
        let successfulCompletions = completedEvents.filter { $0.success }.count
        
        // Count failed completions (tasks that completed but were marked as unsuccessful)
        let failedCompletions = completedEvents.filter { !$0.success }.count
        
        // Total failed includes failed completions, explicit failures, expired tasks, and cancelled tasks
        let totalFailed = failedCompletions + failedEvents.count + expiredEvents.count + cancelledEvents.count
        
        // Calculate average duration from events with duration data
        let eventsWithDuration = completedEvents.filter { $0.duration != nil }
        let averageDuration = eventsWithDuration.isEmpty ? 0 :
            eventsWithDuration.compactMap { $0.duration }.reduce(0, +) / Double(eventsWithDuration.count)
        
        // Success rate calculation: successful completions / total executed attempts
        let successRate: Double
        if totalExecuted > 0 {
            let rate = Double(successfulCompletions) / Double(totalExecuted)
            // Ensure success rate is always between 0.0 and 1.0 (defensive programming)
            successRate = min(max(rate, 0.0), 1.0)
        } else {
            successRate = 0.0
        }
        
        // Find the most recent execution start time
        let lastExecutionDate = (!executedEvents.isEmpty ? executedEvents : completedEvents)
            .max(by: { $0.timestamp < $1.timestamp })?.timestamp
        
        return TaskPerformanceMetrics(
            taskIdentifier: taskIdentifier,
            totalScheduled: scheduledEvents.count,
            totalExecuted: totalExecuted,
            totalCompleted: successfulCompletions, // Only successful completions
            totalFailed: totalFailed,
            averageDuration: averageDuration,
            successRate: successRate,
            lastExecutionDate: lastExecutionDate
        )
    }
    
    func getDailyExecutionPattern() -> [DailyExecutionData] {
        let calendar = Calendar.current
        let allEvents = getAllEvents()
        // Filter to only include task statistics events for pattern analysis
        let statisticsEvents = allEvents.filter { $0.type.isTaskStatisticsEvent }
        let grouped = Dictionary(grouping: statisticsEvents.filter { $0.type == .taskExecutionStarted }) { event in
            calendar.startOfDay(for: event.timestamp)
        }
        
        return grouped.map { date, events in
            let hourlyDistribution = Dictionary(grouping: events) { event in
                calendar.component(.hour, from: event.timestamp)
            }.mapValues { $0.count }
            
            return DailyExecutionData(
                date: date,
                totalExecutions: events.count,
                hourlyDistribution: hourlyDistribution,
                successfulExecutions: events.filter { $0.success }.count
            )
        }.sorted(by: { $0.date < $1.date })
    }
}

// MARK: - Performance Metrics Models

public struct TaskPerformanceMetrics: Codable, Sendable {
    public let taskIdentifier: String
    public let totalScheduled: Int
    public let totalExecuted: Int
    public let totalCompleted: Int
    public let totalFailed: Int
    public let averageDuration: TimeInterval
    public let successRate: Double
    public let lastExecutionDate: Date?
}

public struct DailyExecutionData: Codable, Sendable {
    public let date: Date
    public let totalExecutions: Int
    public let hourlyDistribution: [Int: Int]
    public let successfulExecutions: Int
}
