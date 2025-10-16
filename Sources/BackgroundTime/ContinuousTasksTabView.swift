//
//  ContinuousTasksTabView.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import SwiftUI
import Charts

// MARK: - Continuous Tasks Tab (iOS 26.0+)

@available(iOS 26.0, *)
public struct ContinuousTasksTabView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let selectedTimeRange: TimeRange
    
    public init(viewModel: DashboardViewModel, selectedTimeRange: TimeRange) {
        self.viewModel = viewModel
        self.selectedTimeRange = selectedTimeRange
    }
    
    private var filteredEvents: [BackgroundTaskEvent] {
        return viewModel.events.filter { event in
            selectedTimeRange.contains(event.timestamp)
        }
    }
    
    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Active Continuous Tasks Summary
                continuousTasksSummary
                
                // Active Tasks List
                activeTasksList
                
                // Continuous Tasks Timeline
                continuousTasksTimeline
                
                // Performance Metrics
                continuousTasksPerformance
            }
            .padding()
        }
        .refreshable {
            Task { @MainActor in
                await viewModel.refresh()
            }
        }
    }
    
    @ViewBuilder
    private var continuousTasksSummary: some View {
        let continuousEvents = filteredEvents.filter { $0.type.isContinuousTaskEvent }
        let activeTasks = Set(continuousEvents
            .filter { $0.type == .continuousTaskStarted }
            .map { $0.taskIdentifier })
        let stoppedTasks = Set(continuousEvents
            .filter { $0.type == .continuousTaskStopped }
            .map { $0.taskIdentifier })
        let currentlyActive = activeTasks.subtracting(stoppedTasks)
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Continuous Tasks Overview")
                .font(.headline)
                .padding(.horizontal)
            
            HStack(spacing: 16) {
                StatisticCard(
                    title: "Active Tasks",
                    value: "\(currentlyActive.count)",
                    icon: "infinity.circle.fill",
                    color: .blue
                )
                
                StatisticCard(
                    title: "Total Started",
                    value: "\(activeTasks.count)",
                    icon: "play.circle.fill",
                    color: .green
                )
            }
            
            HStack(spacing: 16) {
                StatisticCard(
                    title: "Completed",
                    value: "\(stoppedTasks.count)",
                    icon: "checkmark.circle.fill",
                    color: .orange
                )
                
                let pausedCount = continuousEvents.filter { $0.type == .continuousTaskPaused }.count
                StatisticCard(
                    title: "Paused",
                    value: "\(pausedCount)",
                    icon: "pause.circle.fill",
                    color: .yellow
                )
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var activeTasksList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Continuous Tasks")
                .font(.headline)
                .padding(.horizontal)
            
            let continuousEvents = filteredEvents.filter { $0.type.isContinuousTaskEvent }
            let tasksByIdentifier = Dictionary(grouping: continuousEvents) { $0.taskIdentifier }
            
            if tasksByIdentifier.isEmpty {
                Text("No continuous tasks found")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(tasksByIdentifier.keys.sorted()), id: \.self) { taskIdentifier in
                        if let events = tasksByIdentifier[taskIdentifier] {
                            ContinuousTaskRow(taskIdentifier: taskIdentifier, events: events)
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var continuousTasksTimeline: some View {
        let continuousEvents = filteredEvents
            .filter { $0.type.isContinuousTaskEvent }
            .sorted { $0.timestamp > $1.timestamp }
        
        if !continuousEvents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Continuous Tasks Timeline")
                    .font(.headline)
                    .padding(.horizontal)
                
                Chart {
                    ForEach(continuousEvents.prefix(20)) { event in
                        PointMark(
                            x: .value("Time", event.timestamp),
                            y: .value("Task", truncateForChart(event.taskIdentifier))
                        )
                        .foregroundStyle(colorForEventType(event.type))
                    }
                }
                .frame(height: 200)
                .padding(.horizontal)
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var continuousTasksPerformance: some View {
        let continuousEvents = filteredEvents.filter { $0.type.isContinuousTaskEvent }
        let taskGroups = Dictionary(grouping: continuousEvents) { $0.taskIdentifier }
        
        if !taskGroups.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Task Performance")
                    .font(.headline)
                    .padding(.horizontal)
                
                LazyVStack(spacing: 8) {
                    ForEach(Array(taskGroups.keys.sorted()), id: \.self) { taskIdentifier in
                        if let events = taskGroups[taskIdentifier] {
                            ContinuousTaskPerformanceCard(taskIdentifier: taskIdentifier, events: events)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    private func colorForEventType(_ type: BackgroundTaskEventType) -> Color {
        switch type {
        case .continuousTaskStarted: return .green
        case .continuousTaskPaused: return .yellow
        case .continuousTaskResumed: return .blue
        case .continuousTaskStopped: return .red
        case .continuousTaskProgress: return .purple
        default: return .gray
        }
    }
    
    /// Truncates task identifiers for display in charts where space is limited
    private func truncateForChart(_ identifier: String) -> String {
        if identifier.count <= 30 {  // Increased from 20
            return identifier
        }
        
        // For charts, use moderate truncation to show more information
        let components = identifier.components(separatedBy: ".")
        if components.count > 1, let lastPart = components.last {
            return lastPart.count <= 25 ? lastPart : String(lastPart.prefix(22)) + "..."
        } else {
            return String(identifier.prefix(27)) + "..."
        }
    }
}

@available(iOS 26.0, *)
public struct ContinuousTaskRow: View {
    let taskIdentifier: String
    let events: [BackgroundTaskEvent]
    
    public init(taskIdentifier: String, events: [BackgroundTaskEvent]) {
        self.taskIdentifier = taskIdentifier
        self.events = events
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(currentStatus.color)
                    .frame(width: 8, height: 8)
                
                TaskIdentifierText(taskIdentifier, font: .caption, maxLines: 3, alwaysExpanded: true)
                
                Spacer()
                
                Text(currentStatus.displayName)
                    .font(.caption2)
                    .foregroundColor(currentStatus.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(currentStatus.color.opacity(0.1))
                    .cornerRadius(4)
            }
            
            if let latestEvent = events.max(by: { $0.timestamp < $1.timestamp }) {
                HStack {
                    Text("Last Update:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(latestEvent.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            // Progress indicator if available
            if events.contains(where: { $0.type == .continuousTaskProgress }) {
                ProgressView(value: 0.7) // Placeholder - you'd extract actual progress from metadata
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private var currentStatus: ContinuousTaskDisplayStatus {
        let sortedEvents = events.sorted { $0.timestamp > $1.timestamp }
        
        for event in sortedEvents {
            switch event.type {
            case .continuousTaskStarted:
                return .running
            case .continuousTaskPaused:
                return .paused
            case .continuousTaskResumed:
                return .running
            case .continuousTaskStopped:
                return .stopped
            case .continuousTaskProgress:
                return .running
            default:
                continue
            }
        }
        return .unknown
    }
}

@available(iOS 26.0, *)
public struct ContinuousTaskPerformanceCard: View {
    let taskIdentifier: String
    let events: [BackgroundTaskEvent]
    
    public init(taskIdentifier: String, events: [BackgroundTaskEvent]) {
        self.taskIdentifier = taskIdentifier
        self.events = events
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TaskIdentifierText(taskIdentifier, font: .subheadline, maxLines: 3, alwaysExpanded: true)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                MetricRow(label: "Events", value: "\(events.count)")
                MetricRow(label: "Restarts", value: "\(resumeCount)")
                MetricRow(label: "Avg Duration", value: averageDuration)
                MetricRow(label: "Last Seen", value: lastEventTime)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
    
    private var resumeCount: Int {
        events.filter { $0.type == .continuousTaskResumed }.count
    }
    
    private var averageDuration: String {
        let durations = events.compactMap { $0.duration }
        guard !durations.isEmpty else { return "N/A" }
        let average = durations.reduce(0, +) / Double(durations.count)
        return String(format: "%.1fs", average)
    }
    
    private var lastEventTime: String {
        guard let lastEvent = events.max(by: { $0.timestamp < $1.timestamp }) else { return "N/A" }
        return lastEvent.timestamp.formatted(.relative(presentation: .numeric))
    }
}
