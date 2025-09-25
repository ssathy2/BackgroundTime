//
//  BackgroundTimeDashboard.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import SwiftUI
import Charts
import BackgroundTasks

// MARK: - Enums and Types

enum DashboardTab: CaseIterable {
    case overview, timeline, performance, errors, continuousTasks
    
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .timeline: return "Timeline"
        case .performance: return "Performance"
        case .errors: return "Errors"
        case .continuousTasks: return "Continuous"
        }
    }
    
    var systemImage: String {
        switch self {
        case .overview: return "chart.bar.fill"
        case .timeline: return "clock.fill"
        case .performance: return "speedometer"
        case .errors: return "exclamationmark.triangle.fill"
        case .continuousTasks: return "infinity.circle.fill"
        }
    }
    
    @available(iOS 26.0, *)
    static var allCasesForCurrentOS: [DashboardTab] {
        return DashboardTab.allCases
    }
    
    static var allCasesForLegacyOS: [DashboardTab] {
        return [.overview, .timeline, .performance, .errors]
    }
}

enum TimeRange: String, CaseIterable {
    case last1Hour = "1h"
    case last6Hours = "6h"
    case last24Hours = "24h"
    case last7Days = "7d"
    
    var displayName: String {
        switch self {
        case .last1Hour: return "1 Hour"
        case .last6Hours: return "6 Hours"
        case .last24Hours: return "24 Hours"
        case .last7Days: return "7 Days"
        }
    }
    
    var timeInterval: TimeInterval {
        switch self {
        case .last1Hour: return 3600
        case .last6Hours: return 21600
        case .last24Hours: return 86400
        case .last7Days: return 604800
        }
    }
}

// MARK: - iOS Version Support Helpers

extension UIDevice {
    /// Returns true if the current device supports Continuous Background Tasks (iOS 26.0+)
    static var supportsContinuousBackgroundTasks: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }
}

// MARK: - Main Dashboard View

@available(iOS 16.0, *)
public struct BackgroundTimeDashboard: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedTimeRange: TimeRange = .last24Hours
    @State private var selectedTab: DashboardTab = .overview
    @State private var showingError = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Time Range Picker
                timeRangePicker
                
                // Tab View
                TabView(selection: $selectedTab) {
                    OverviewTabView(viewModel: viewModel)
                        .tabItem {
                            Label("Overview", systemImage: "chart.bar.fill")
                        }
                        .tag(DashboardTab.overview)
                    
                    TimelineTabView(viewModel: viewModel)
                        .tabItem {
                            Label("Timeline", systemImage: "clock.fill")
                        }
                        .tag(DashboardTab.timeline)
                    
                    PerformanceTabView(viewModel: viewModel)
                        .tabItem {
                            Label("Performance", systemImage: "speedometer")
                        }
                        .tag(DashboardTab.performance)
                    
                    ErrorsTabView(viewModel: viewModel)
                        .tabItem {
                            Label("Errors", systemImage: "exclamationmark.triangle.fill")
                        }
                        .tag(DashboardTab.errors)
                    
                    // Continuous Tasks Tab (iOS 26.0+)
                    if #available(iOS 26.0, *) {
                        ContinuousTasksTabView(viewModel: viewModel)
                            .tabItem {
                                Label("Continuous", systemImage: "infinity.circle.fill")
                            }
                            .tag(DashboardTab.continuousTasks)
                    }
                }
            }
            .navigationTitle("BackgroundTime")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { 
                        Task { @MainActor in
                            viewModel.refresh()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
        .onAppear {
            Task { @MainActor in
                if viewModel.events.isEmpty && !viewModel.isLoading {
                    viewModel.loadData(for: selectedTimeRange)
                }
            }
        }
        .onChange(of: selectedTimeRange) { _, newRange in
            Task { @MainActor in
                viewModel.loadData(for: newRange)
            }
        }
        .onChange(of: viewModel.error) { _, newError in
            showingError = newError != nil
        }
    }
    
    private var timeRangePicker: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
    
    /// Available dashboard tabs based on current iOS version
    private var availableTabs: [DashboardTab] {
        if UIDevice.supportsContinuousBackgroundTasks {
            if #available(iOS 26.0, *) {
                return DashboardTab.allCasesForCurrentOS
            }
        }
        return DashboardTab.allCasesForLegacyOS
    }
}

// MARK: - Overview Tab

@available(iOS 16.0, *)
struct OverviewTabView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Loading indicator
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
                
                // No data message
                if !viewModel.isLoading && viewModel.events.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No events found for selected time range")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Try selecting a different time range or wait for background tasks to execute.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
                
                // Statistics Cards
                if !viewModel.isLoading && !viewModel.events.isEmpty {
                    HStack(spacing: 16) {
                        StatisticCard(
                            title: "Total Executed",
                            value: "\(viewModel.statistics?.totalTasksExecuted ?? 0)",
                            icon: "play.fill",
                            color: .blue
                        )
                        
                        StatisticCard(
                            title: "Success Rate",
                            value: String(format: "%.1f%%", (viewModel.statistics?.successRate ?? 0) * 100),
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                    }
                
                    HStack(spacing: 16) {
                        StatisticCard(
                            title: "Failed Tasks",
                            value: "\(viewModel.statistics?.totalTasksFailed ?? 0)",
                            icon: "xmark.circle.fill",
                            color: .red
                        )
                        
                        StatisticCard(
                            title: "Avg Duration",
                            value: String(format: "%.1fs", viewModel.statistics?.averageExecutionTime ?? 0),
                            icon: "timer",
                            color: .orange
                        )
                    }
                }
                
                // Continuous Tasks Section (iOS 26.0+)
                if #available(iOS 26.0, *), UIDevice.supportsContinuousBackgroundTasks, !viewModel.isLoading {
                    continuousTasksOverviewSection
                }
                
                // Execution Pattern Chart
                if let hourlyData = viewModel.statistics?.executionsByHour, !viewModel.isLoading, !hourlyData.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Executions by Hour")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Chart {
                            ForEach(Array(hourlyData.keys.sorted()), id: \.self) { hour in
                                BarMark(
                                    x: .value("Hour", hour),
                                    y: .value("Count", hourlyData[hour] ?? 0)
                                )
                                .foregroundStyle(.blue)
                            }
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                
                // Recent Events
                if !viewModel.isLoading {
                    RecentEventsView(events: Array(viewModel.events.prefix(10)))
                }
            }
            .padding()
        }
        .refreshable {
            Task { @MainActor in
                viewModel.refresh()
            }
        }
    }
    
    // MARK: - Continuous Tasks Overview Section (iOS 26.0+)
    
    @available(iOS 26.0, *)
    @ViewBuilder
    private var continuousTasksOverviewSection: some View {
        let continuousEvents = viewModel.events.filter { $0.type.isContinuousTaskEvent }
        
        if !continuousEvents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Continuous Tasks")
                    .font(.headline)
                    .padding(.horizontal)
                
                HStack(spacing: 16) {
                    let activeTasks = Set(continuousEvents
                        .filter { $0.type == .continuousTaskStarted }
                        .map { $0.taskIdentifier })
                    let stoppedTasks = Set(continuousEvents
                        .filter { $0.type == .continuousTaskStopped }
                        .map { $0.taskIdentifier })
                    let currentlyActive = activeTasks.subtracting(stoppedTasks)
                    
                    StatisticCard(
                        title: "Active Tasks",
                        value: "\(currentlyActive.count)",
                        icon: "infinity.circle.fill",
                        color: .purple
                    )
                    
                    StatisticCard(
                        title: "Total Events",
                        value: "\(continuousEvents.count)",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .indigo
                    )
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Timeline Tab

@available(iOS 16.0, *)
struct TimelineTabView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(viewModel.timelineData.enumerated()), id: \.element.id) { index, dataPoint in
                    TimelineRowView(
                        dataPoint: dataPoint,
                        isLast: index == viewModel.timelineData.count - 1
                    )
                }
            }
            .padding()
        }
        .refreshable {
            Task { @MainActor in
                viewModel.refresh()
            }
        }
    }
}

// MARK: - Performance Tab

@available(iOS 16.0, *)
struct PerformanceTabView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Duration Chart
                if !viewModel.events.isEmpty {
                    let durationEvents = viewModel.events.compactMap { event -> (Date, TimeInterval)? in
                        guard let duration = event.duration, event.type == .taskExecutionCompleted else { return nil }
                        return (event.timestamp, duration)
                    }
                    
                    if !durationEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Execution Duration Over Time")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Chart {
                                ForEach(Array(durationEvents.enumerated()), id: \.offset) { index, data in
                                    LineMark(
                                        x: .value("Time", data.0),
                                        y: .value("Duration", data.1)
                                    )
                                    .foregroundStyle(.blue)
                                }
                            }
                            .frame(height: 200)
                            .padding(.horizontal)
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
                
                // Task Performance Metrics
                ForEach(viewModel.taskMetrics, id: \.taskIdentifier) { metric in
                    TaskMetricCard(metric: metric)
                }
            }
            .padding()
        }
        .refreshable {
            Task { @MainActor in
                viewModel.refresh()
            }
        }
    }
}

// MARK: - Errors Tab

@available(iOS 16.0, *)
struct ErrorsTabView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Error Summary
                if let errorsByType = viewModel.statistics?.errorsByType,
                   !errorsByType.isEmpty {
                    ErrorSummarySection(errorsByType: errorsByType)
                }
                
                // Failed Events
                failedEventsSection
            }
            .padding()
        }
        .refreshable {
            Task { @MainActor in
                viewModel.refresh()
            }
        }
    }
    
    struct ErrorSummarySection: View {
        let errorsByType: [String: Int]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Error Types")
                    .font(.headline)
                    .padding(.horizontal)
                
                Chart {
                    ForEach(Array(errorsByType.keys).sorted(), id: \.self) { errorType in
                        BarMark(
                            x: .value("Count", errorsByType[errorType] ?? 0),
                            y: .value("Error Type", String(errorType.prefix(30)))
                        )
                        .foregroundStyle(.red)
                    }
                }
                .frame(height: max(200.0, CGFloat(errorsByType.count) * 30.0))
                .padding(.horizontal)
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var failedEventsSection: some View {
        let failedEvents = viewModel.events.filter { !$0.success }
        ForEach(failedEvents) { event in
            ErrorEventCard(event: event)
        }
    }
}

// MARK: - Continuous Tasks Tab (iOS 26.0+)

@available(iOS 26.0, *)
struct ContinuousTasksTabView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
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
                viewModel.refresh()
            }
        }
    }
    
    @ViewBuilder
    private var continuousTasksSummary: some View {
        let continuousEvents = viewModel.events.filter { $0.type.isContinuousTaskEvent }
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
            
            let continuousEvents = viewModel.events.filter { $0.type.isContinuousTaskEvent }
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
        let continuousEvents = viewModel.events
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
                            y: .value("Task", event.taskIdentifier)
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
        let continuousEvents = viewModel.events.filter { $0.type.isContinuousTaskEvent }
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
}

@available(iOS 26.0, *)
struct ContinuousTaskRow: View {
    let taskIdentifier: String
    let events: [BackgroundTaskEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(currentStatus.color)
                    .frame(width: 8, height: 8)
                
                Text(taskIdentifier)
                    .font(.caption)
                    .fontWeight(.medium)
                
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
            if let progressEvent = events.filter({ $0.type == .continuousTaskProgress }).last {
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
struct ContinuousTaskPerformanceCard: View {
    let taskIdentifier: String
    let events: [BackgroundTaskEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(taskIdentifier)
                .font(.subheadline)
                .fontWeight(.medium)
            
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

@available(iOS 26.0, *)
enum ContinuousTaskDisplayStatus {
    case running, paused, stopped, unknown
    
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .paused: return "Paused"
        case .stopped: return "Stopped"
        case .unknown: return "Unknown"
        }
    }
    
    var color: Color {
        switch self {
        case .running: return .green
        case .paused: return .yellow
        case .stopped: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Supporting Views

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct RecentEventsView: View {
    let events: [BackgroundTaskEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Events")
                .font(.headline)
            
            if events.isEmpty {
                Text("No recent events")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(events) { event in
                        HStack {
                            Image(systemName: event.type.icon)
                                .foregroundColor(event.success ? .green : .red)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.taskIdentifier)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Text(event.type.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(event.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct TimelineRowView: View {
    let dataPoint: TimelineDataPoint
    let isLast: Bool
    
    init(dataPoint: TimelineDataPoint, isLast: Bool = false) {
        self.dataPoint = dataPoint
        self.isLast = isLast
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack {
                Circle()
                    .fill(dataPoint.success ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                if !isLast {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 20)
                }
            }
            
            // Event details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dataPoint.taskIdentifier)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(dataPoint.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(dataPoint.eventType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let duration = dataPoint.duration {
                    Text(String(format: "Duration: %.2fs", duration))
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct TaskMetricCard: View {
    let metric: TaskPerformanceMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(metric.taskIdentifier)
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                MetricRow(label: "Scheduled", value: "\(metric.totalScheduled)")
                MetricRow(label: "Executed", value: "\(metric.totalExecuted)")
                MetricRow(label: "Completed", value: "\(metric.totalCompleted)")
                MetricRow(label: "Failed", value: "\(metric.totalFailed)")
                MetricRow(label: "Success Rate", value: String(format: "%.1f%%", metric.successRate * 100))
                MetricRow(label: "Avg Duration", value: String(format: "%.2fs", metric.averageDuration))
            }
            
            if let lastExecution = metric.lastExecutionDate {
                Text("Last execution: \(lastExecution, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.medium)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ErrorEventCard: View {
    let event: BackgroundTaskEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                Text(event.taskIdentifier)
                    .font(.headline)
                
                Spacer()
                
                Text(event.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let errorMessage = event.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Text(event.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Extensions

extension BackgroundTaskEventType {
    var icon: String {
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
        case .initialization:
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
