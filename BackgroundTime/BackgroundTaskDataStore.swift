//
//  BackgroundTaskDataStore.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Foundation
import os.log

// MARK: - Data Storage Manager

class BackgroundTaskDataStore {
    static let shared = BackgroundTaskDataStore()
    
    private let logger = Logger(subsystem: "BackgroundTime", category: "DataStore")
    private let eventStore: ThreadSafeDataStore<BackgroundTaskEvent>
    private let performanceMonitor = AccessPatternMonitor.shared
    
    private let userDefaults = UserDefaults(suiteName: "BackgroundTime.DataStore")
    private let eventsKey = "BackgroundTime.StoredEvents"
    
    private init() {
        // Initialize with default capacity
        self.eventStore = ThreadSafeDataStore<BackgroundTaskEvent>(capacity: 1000)
        loadPersistedEvents()
    }
    
    func configure(maxStoredEvents: Int) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        eventStore.resize(to: maxStoredEvents)
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        performanceMonitor.recordAccess(operation: "configure", duration: duration)
        
        logger.info("Configured data store with max events: \(maxStoredEvents)")
    }
    
    func recordEvent(_ event: BackgroundTaskEvent) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let droppedEvent = eventStore.append(event)
        persistEvents()
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        performanceMonitor.recordAccess(operation: "recordEvent", duration: duration)
        
        if droppedEvent != nil {
            logger.warning("Event dropped due to capacity limit: \(droppedEvent!.taskIdentifier)")
        }
        
        logger.info("Recorded event: \(event.type.rawValue) for task: \(event.taskIdentifier)")
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
        let totalScheduled = events.filter { $0.type == .taskScheduled }.count
        let totalExecuted = events.filter { $0.type == .taskExecutionStarted }.count
        let totalCompleted = events.filter { $0.type == .taskExecutionCompleted && $0.success }.count
        let totalFailed = events.filter { $0.type == .taskFailed || ($0.type == .taskExecutionCompleted && !$0.success) }.count
        let totalExpired = events.filter { $0.type == .taskExpired }.count
        
        let completedEvents = events.filter { 
            $0.type == .taskExecutionCompleted && $0.duration != nil 
        }
        
        let averageExecutionTime = completedEvents.isEmpty ? 0 : 
            completedEvents.compactMap { $0.duration }.reduce(0, +) / Double(completedEvents.count)
        
        let successRate = totalExecuted > 0 ? Double(totalCompleted) / Double(totalExecuted) : 0
        
        let executionsByHour = Dictionary(grouping: events.filter { $0.type == .taskExecutionStarted }) { event in
            Calendar.current.component(.hour, from: event.timestamp)
        }.mapValues { $0.count }
        
        let errorsByType = Dictionary(grouping: events.filter { !$0.success && $0.errorMessage != nil }) { event in
            event.errorMessage ?? "Unknown Error"
        }.mapValues { $0.count }
        
        let lastExecutionTime = events
            .filter { $0.type == .taskExecutionStarted }
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
        
        logger.info("Cleared all stored events")
    }
    
    // MARK: - Private Methods
    
    private func persistEvents() {
        do {
            let events = eventStore.toArray()
            let data = try JSONEncoder().encode(events)
            userDefaults?.set(data, forKey: eventsKey)
        } catch {
            logger.error("Failed to persist events: \(error.localizedDescription)")
        }
    }
    
    private func loadPersistedEvents() {
        guard let data = userDefaults?.data(forKey: eventsKey) else { return }
        
        do {
            let events = try JSONDecoder().decode([BackgroundTaskEvent].self, from: data)
            eventStore.append(contentsOf: events)
            logger.info("Loaded \(events.count) persisted events")
        } catch {
            logger.error("Failed to load persisted events: \(error.localizedDescription)")
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
    
    private func generateTaskMetrics(for taskIdentifier: String, from taskEvents: [BackgroundTaskEvent]) -> TaskPerformanceMetrics? {
        guard !taskEvents.isEmpty else { return nil }
        
        let scheduledEvents = taskEvents.filter { $0.type == .taskScheduled }
        let executedEvents = taskEvents.filter { $0.type == .taskExecutionStarted }
        let completedEvents = taskEvents.filter { $0.type == .taskExecutionCompleted }
        let failedEvents = taskEvents.filter { $0.type == .taskFailed || ($0.type == .taskExecutionCompleted && !$0.success) }
        
        let averageDuration = completedEvents.compactMap { $0.duration }.isEmpty ? 0 :
            completedEvents.compactMap { $0.duration }.reduce(0, +) / Double(completedEvents.count)
        
        let successRate = executedEvents.count > 0 ? 
            Double(completedEvents.filter { $0.success }.count) / Double(executedEvents.count) : 0
        
        return TaskPerformanceMetrics(
            taskIdentifier: taskIdentifier,
            totalScheduled: scheduledEvents.count,
            totalExecuted: executedEvents.count,
            totalCompleted: completedEvents.count,
            totalFailed: failedEvents.count,
            averageDuration: averageDuration,
            successRate: successRate,
            lastExecutionDate: executedEvents.max(by: { $0.timestamp < $1.timestamp })?.timestamp
        )
    }
    
    func getDailyExecutionPattern() -> [DailyExecutionData] {
        let calendar = Calendar.current
        let allEvents = getAllEvents() // Get events from the data store
        let grouped = Dictionary(grouping: allEvents.filter { $0.type == .taskExecutionStarted }) { event in
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

public struct TaskPerformanceMetrics: Codable {
    public let taskIdentifier: String
    public let totalScheduled: Int
    public let totalExecuted: Int
    public let totalCompleted: Int
    public let totalFailed: Int
    public let averageDuration: TimeInterval
    public let successRate: Double
    public let lastExecutionDate: Date?
}

public struct DailyExecutionData: Codable {
    public let date: Date
    public let totalExecutions: Int
    public let hourlyDistribution: [Int: Int]
    public let successfulExecutions: Int
}
