//
//  DashboardViewModel.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var statistics: BackgroundTaskStatistics?
    @Published var events: [BackgroundTaskEvent] = []
    @Published var timelineData: [TimelineDataPoint] = []
    @Published var taskMetrics: [TaskPerformanceMetrics] = []
    @Published var continuousTasksInfo: [Any] = [] // Will be [ContinuousTaskInfo] on iOS 26+
    @Published var isLoading = false
    @Published var error: String?
    
    private let dataStore: BackgroundTaskDataStore
    private var cancellables = Set<AnyCancellable>()
    private var currentTimeRange: TimeRange = .last24Hours
    
    /// The currently selected time range for filtering data
    var selectedTimeRange: TimeRange {
        currentTimeRange
    }
    
    init(dataStore: BackgroundTaskDataStore = BackgroundTaskDataStore.shared) {
        self.dataStore = dataStore
        
        // Auto-refresh every 30 seconds
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }
    
    func loadData(for timeRange: TimeRange) {
        // Don't reload if we're already showing this time range and not loading
        if currentTimeRange == timeRange && !isLoading {
            return
        }
        
        currentTimeRange = timeRange
        isLoading = true
        error = nil
        
        Task {
            do {
                let endDate = Date()
                let startDate = Date(timeIntervalSinceNow: -timeRange.timeInterval)
                
                // Load filtered events
                let filteredEvents = dataStore.getEventsInDateRange(from: startDate, to: endDate)
                
                // Generate statistics based on filtered events
                let stats = dataStore.generateStatistics(for: filteredEvents, in: startDate...endDate)
                
                // Generate timeline data
                let timeline = filteredEvents.map { event in
                    TimelineDataPoint(
                        timestamp: event.timestamp,
                        eventType: event.type,
                        taskIdentifier: event.taskIdentifier,
                        duration: event.duration,
                        success: event.success
                    )
                }.sorted(by: { $0.timestamp > $1.timestamp })
                
                // Generate task metrics for filtered events
                let uniqueTaskIdentifiers = Set(filteredEvents.map { $0.taskIdentifier })
                let metrics = uniqueTaskIdentifiers.compactMap { identifier in
                    dataStore.getTaskPerformanceMetrics(for: identifier, in: startDate...endDate)
                }.sorted(by: { $0.taskIdentifier < $1.taskIdentifier })
                
                await MainActor.run {
                    self.statistics = stats
                    self.events = filteredEvents.sorted(by: { $0.timestamp > $1.timestamp })
                    self.timelineData = timeline
                    self.taskMetrics = metrics
                    
                    // Process continuous tasks data for iOS 26+
                    if #available(iOS 26.0, *) {
                        self.processContinuousTasksData(from: filteredEvents)
                    }
                    
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func refresh() {
        loadData(for: currentTimeRange)
    }
    
    func clearAllData() {
        dataStore.clearAllEvents()
        loadData(for: currentTimeRange)
    }
    
    func exportData() -> BackgroundTaskDashboardData {
        return BackgroundTime.shared.exportDataForDashboard()
    }
    
    func syncWithDashboard() async {
        do {
            try await BackgroundTime.shared.syncWithDashboard()
        } catch {
            await MainActor.run {
                self.error = "Sync failed: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Continuous Tasks Support (iOS 26.0+)
    
    @available(iOS 26.0, *)
    private func processContinuousTasksData(from events: [BackgroundTaskEvent]) {
        let continuousEvents = events.filter { $0.type.isContinuousTaskEvent }
        let taskGroups = Dictionary(grouping: continuousEvents) { $0.taskIdentifier }
        
        var continuousTasksInfoTyped: [ContinuousTaskInfo] = []
        
        for (taskIdentifier, events) in taskGroups {
            let sortedEvents = events.sorted { $0.timestamp < $1.timestamp }
            
            guard let firstEvent = sortedEvents.first else { continue }
            
            // Determine current status
            var currentStatus: ContinuousTaskStatus = .running
            for event in sortedEvents.reversed() {
                switch event.type {
                case .continuousTaskStarted:
                    currentStatus = .running
                    break
                case .continuousTaskPaused:
                    currentStatus = .paused
                    break
                case .continuousTaskResumed:
                    currentStatus = .running
                    break
                case .continuousTaskStopped:
                    currentStatus = .stopped
                    break
                default:
                    continue
                }
            }
            
            // Calculate metrics
            let resumeEvents = sortedEvents.filter { $0.type == .continuousTaskResumed }
            let progressEvents = sortedEvents.filter { $0.type == .continuousTaskProgress }
            
            let progressUpdates = progressEvents.map { event in
                ContinuousTaskProgress(
                    timestamp: event.timestamp,
                    completedUnitCount: 0, // Would extract from metadata in real implementation
                    totalUnitCount: 100,   // Would extract from metadata in real implementation
                    localizedDescription: event.errorMessage
                )
            }
            
            let continuousTaskInfo = ContinuousTaskInfo(
                taskIdentifier: taskIdentifier,
                startTime: firstEvent.timestamp,
                currentStatus: currentStatus,
                totalRunTime: calculateTotalRunTime(events: sortedEvents),
                pausedTime: 0, // Would calculate from pause/resume events
                resumeCount: resumeEvents.count,
                progressUpdates: progressUpdates,
                expectedDuration: sortedEvents.compactMap { $0.duration }.first,
                priority: .medium // Would extract from metadata in real implementation
            )
            
            continuousTasksInfoTyped.append(continuousTaskInfo)
        }
        
        // Update the published property
        continuousTasksInfo = continuousTasksInfoTyped
    }
    
    @available(iOS 26.0, *)
    private func calculateTotalRunTime(events: [BackgroundTaskEvent]) -> TimeInterval {
        // This is a simplified calculation - in a real implementation you'd track
        // the time between start/pause and resume/stop events
        var totalRunTime: TimeInterval = 0
        var currentStartTime: Date?
        
        for event in events.sorted(by: { $0.timestamp < $1.timestamp }) {
            switch event.type {
            case .continuousTaskStarted, .continuousTaskResumed:
                currentStartTime = event.timestamp
            case .continuousTaskPaused, .continuousTaskStopped:
                if let startTime = currentStartTime {
                    totalRunTime += event.timestamp.timeIntervalSince(startTime)
                    currentStartTime = nil
                }
            default:
                break
            }
        }
        
        // If task is still running, add time since last start
        if let startTime = currentStartTime {
            totalRunTime += Date().timeIntervalSince(startTime)
        }
        
        return totalRunTime
    }
    
    /// Returns continuous tasks info with proper typing for iOS 26+
    @available(iOS 26.0, *)
    var continuousTasksInfoTyped: [ContinuousTaskInfo] {
        return continuousTasksInfo.compactMap { $0 as? ContinuousTaskInfo }
    }
}
