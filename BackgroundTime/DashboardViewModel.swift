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
    @Published var isLoading = false
    @Published var error: String?
    
    private let dataStore = BackgroundTaskDataStore.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Auto-refresh every 30 seconds
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }
    
    func loadData(for timeRange: TimeRange) {
        isLoading = true
        error = nil
        
        Task {
            do {
                let endDate = Date()
                let startDate = Date(timeIntervalSinceNow: -timeRange.timeInterval)
                
                // Load filtered events
                let filteredEvents = dataStore.getEventsInDateRange(from: startDate, to: endDate)
                
                // Generate statistics
                let stats = dataStore.generateStatistics()
                
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
                
                // Generate task metrics
                let uniqueTaskIdentifiers = Set(filteredEvents.map { $0.taskIdentifier })
                let metrics = uniqueTaskIdentifiers.compactMap { identifier in
                    dataStore.getTaskPerformanceMetrics(for: identifier)
                }.sorted(by: { $0.taskIdentifier < $1.taskIdentifier })
                
                await MainActor.run {
                    self.statistics = stats
                    self.events = filteredEvents.sorted(by: { $0.timestamp > $1.timestamp })
                    self.timelineData = timeline
                    self.taskMetrics = metrics
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
        loadData(for: .last24Hours) // Default refresh to last 24 hours
    }
    
    func clearAllData() {
        dataStore.clearAllEvents()
        loadData(for: .last24Hours)
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
}
