//
//  BackgroundTimeDashboard.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import SwiftUI
import Charts

// MARK: - Main Dashboard View

@available(iOS 16.0, *)
public struct BackgroundTimeDashboard: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedTimeRange: TimeRange = .last24Hours
    @State private var selectedTab: DashboardTab = .overview
    
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
                }
            }
            .navigationTitle("BackgroundTime")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadData(for: selectedTimeRange)
        }
        .onChange(of: selectedTimeRange) { _, newRange in
            viewModel.loadData(for: newRange)
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
}

// MARK: - Overview Tab

@available(iOS 16.0, *)
struct OverviewTabView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Statistics Cards
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
                        icon: "timer.fill",
                        color: .orange
                    )
                }
                
                // Execution Pattern Chart
                if let hourlyData = viewModel.statistics?.executionsByHour {
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
                RecentEventsView(events: Array(viewModel.events.prefix(10)))
            }
            .padding()
        }
        .refreshable {
            viewModel.refresh()
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
            viewModel.refresh()
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
            viewModel.refresh()
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
            viewModel.refresh()
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
        }
    }
}

// MARK: - Enums

enum DashboardTab: CaseIterable {
    case overview, timeline, performance, errors
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
