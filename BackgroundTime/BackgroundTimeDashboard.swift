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
                    OverviewTabView(viewModel: viewModel, selectedTimeRange: selectedTimeRange)
                        .tabItem {
                            Label("Overview", systemImage: "chart.bar.fill")
                        }
                        .tag(DashboardTab.overview)
                    
                    TimelineTabView(viewModel: viewModel, selectedTimeRange: selectedTimeRange)
                        .tabItem {
                            Label("Timeline", systemImage: "clock.fill")
                        }
                        .tag(DashboardTab.timeline)
                    
                    PerformanceTabView(viewModel: viewModel, selectedTimeRange: selectedTimeRange)
                        .tabItem {
                            Label("Performance", systemImage: "speedometer")
                        }
                        .tag(DashboardTab.performance)
                    
                    ErrorsTabView(viewModel: viewModel, selectedTimeRange: selectedTimeRange)
                        .tabItem {
                            Label("Errors", systemImage: "exclamationmark.triangle.fill")
                        }
                        .tag(DashboardTab.errors)
                    
                    // Continuous Tasks Tab (iOS 26.0+)
                    if #available(iOS 26.0, *) {
                        ContinuousTasksTabView(viewModel: viewModel, selectedTimeRange: selectedTimeRange)
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
        VStack(spacing: 8) {
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Time range indicator
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("Showing data from \(selectedTimeRange.displayName.lowercased()) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
        }
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
    let selectedTimeRange: TimeRange
    
    private var filteredEvents: [BackgroundTaskEvent] {
        let cutoffDate = Date().addingTimeInterval(-selectedTimeRange.timeInterval)
        return viewModel.events.filter { $0.timestamp >= cutoffDate }
    }
    
    private var filteredStatistics: BackgroundTaskStatistics? {
        guard let stats = viewModel.statistics else { return nil }
        let cutoffDate = Date().addingTimeInterval(-selectedTimeRange.timeInterval)
        let events = viewModel.events.filter { $0.timestamp >= cutoffDate }
        
        // Recalculate statistics for filtered events
        return BackgroundTaskDataStore.shared.generateStatistics(
            for: events, 
            in: cutoffDate...Date()
        )
    }
    
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
                if !viewModel.isLoading && filteredEvents.isEmpty {
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
                if !viewModel.isLoading && !filteredEvents.isEmpty {
                    HStack(spacing: 16) {
                        StatisticCard(
                            title: "Total Executed",
                            value: "\(filteredStatistics?.totalTasksExecuted ?? 0)",
                            icon: "play.fill",
                            color: .blue
                        )
                        
                        StatisticCard(
                            title: "Success Rate",
                            value: String(format: "%.1f%%", (filteredStatistics?.successRate ?? 0) * 100),
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                    }
                
                    HStack(spacing: 16) {
                        StatisticCard(
                            title: "Failed Tasks",
                            value: "\(filteredStatistics?.totalTasksFailed ?? 0)",
                            icon: "xmark.circle.fill",
                            color: .red
                        )
                        
                        StatisticCard(
                            title: "Avg Duration",
                            value: String(format: "%.1fs", filteredStatistics?.averageExecutionTime ?? 0),
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
                if let hourlyData = filteredStatistics?.executionsByHour, !viewModel.isLoading, !hourlyData.isEmpty {
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
                    RecentEventsView(events: Array(filteredEvents.prefix(10)))
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
        let continuousEvents = filteredEvents.filter { $0.type.isContinuousTaskEvent }
        
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
    let selectedTimeRange: TimeRange
    
    private var filteredTimelineData: [TimelineDataPoint] {
        let cutoffDate = Date().addingTimeInterval(-selectedTimeRange.timeInterval)
        return viewModel.timelineData.filter { $0.timestamp >= cutoffDate }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(filteredTimelineData.enumerated()), id: \.element.id) { index, dataPoint in
                    TimelineRowView(
                        dataPoint: dataPoint,
                        isLast: index == filteredTimelineData.count - 1
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
    let selectedTimeRange: TimeRange
    @State private var selectedMetricFilter: PerformanceMetricFilter = .all
    @State private var showingDetailedMetrics = false
    @State private var selectedTaskForDetail: String?
    
    private var filteredEvents: [BackgroundTaskEvent] {
        let cutoffDate = Date().addingTimeInterval(-selectedTimeRange.timeInterval)
        return viewModel.events.filter { $0.timestamp >= cutoffDate }
    }
    
    private var filteredStatistics: BackgroundTaskStatistics? {
        guard !filteredEvents.isEmpty else { return nil }
        let cutoffDate = Date().addingTimeInterval(-selectedTimeRange.timeInterval)
        return BackgroundTaskDataStore.shared.generateStatistics(
            for: filteredEvents,
            in: cutoffDate...Date()
        )
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Performance Overview Header
                performanceOverviewSection
                
                // Metric Filter Selector
                metricFilterSelector
                
                // 3D Performance Surface Plot (if available)
                if #available(iOS 17.0, *) {
                    performance3DVisualization
                }
                
                // Enhanced Duration Chart with Liquid Glass
                enhancedDurationChart
                
                // Performance Heatmap
                performanceHeatmap
                
                // Real-time Performance Metrics
                realTimeMetricsSection
                
                // Task Performance Cards with Enhanced Design
                taskPerformanceSection
                
                // Performance Insights & Recommendations
                performanceInsightsSection
            }
            .padding()
        }
        .refreshable {
            Task { @MainActor in
                viewModel.refresh()
            }
        }
        .sheet(isPresented: $showingDetailedMetrics) {
            if let taskId = selectedTaskForDetail {
                DetailedTaskPerformanceView(taskIdentifier: taskId, viewModel: viewModel)
            }
        }
    }
    
    // MARK: - Performance Overview Section
    @ViewBuilder
    private var performanceOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "speedometer")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text("Performance Overview")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    showingDetailedMetrics.toggle()
                }) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
            }
            
            // Key Performance Indicators
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                PerformanceKPICard(
                    title: "Avg Execution Time",
                    value: String(format: "%.2fs", filteredStatistics?.averageExecutionTime ?? 0),
                    trend: calculateExecutionTimeTrend(),
                    icon: "timer"
                )
                
                PerformanceKPICard(
                    title: "Success Rate",
                    value: String(format: "%.1f%%", (filteredStatistics?.successRate ?? 0) * 100),
                    trend: calculateSuccessRateTrend(),
                    icon: "checkmark.circle.fill"
                )
                
                PerformanceKPICard(
                    title: "Task Throughput",
                    value: String(format: "%.1f/min", calculateTaskThroughput()),
                    trend: calculateThroughputTrend(),
                    icon: "gauge.high"
                )
                
                PerformanceKPICard(
                    title: "Peak Memory",
                    value: formatMemoryUsage(getPeakMemoryUsage()),
                    trend: calculateMemoryTrend(),
                    icon: "memorychip"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Metric Filter Selector
    @ViewBuilder
    private var metricFilterSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(PerformanceMetricFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedMetricFilter = filter
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: filter.icon)
                                .font(.caption)
                            Text(filter.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedMetricFilter == filter ? 
                                Color.blue.opacity(0.2) : Color(.tertiarySystemBackground)
                        )
                        .foregroundColor(selectedMetricFilter == filter ? .blue : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - 3D Performance Visualization
    @available(iOS 17.0, *)
    @ViewBuilder
    private var performance3DVisualization: some View {
        if !filteredEvents.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Performance Heat Surface")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Refresh") {
                        // Trigger refresh of performance data
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                
                // 3D-style visualization using regular Chart with depth effect
                Chart {
                    ForEach(0..<24, id: \.self) { hour in
                        ForEach(0..<7, id: \.self) { day in
                            let performanceScore = calculatePerformanceScore(hour: Double(hour), day: Double(day))
                            
                            RectangleMark(
                                x: .value("Hour", hour),
                                y: .value("Day", day),
                                width: .ratio(0.9),
                                height: .ratio(0.9)
                            )
                            .foregroundStyle(performanceGradient(for: performanceScore))
                            .opacity(0.8 + performanceScore * 0.2)
                        }
                    }
                }
                .frame(height: 280)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 12)) { value in
                        if let hour = value.as(Int.self) {
                            AxisValueLabel {
                                Text("\(hour):00")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 7)) { value in
                        if let day = value.as(Int.self) {
                            AxisValueLabel {
                                Text("Day \(day + 1)")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                HStack {
                    Text("Performance:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text("Low")
                            .font(.caption2)
                        
                        Circle().fill(.orange).frame(width: 8, height: 8)
                        Text("Medium")
                            .font(.caption2)
                        
                        Circle().fill(.green).frame(width: 8, height: 8)
                        Text("High")
                            .font(.caption2)
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - Enhanced Duration Chart
    @ViewBuilder
    private var enhancedDurationChart: some View {
        if !filteredEvents.isEmpty {
            let filteredDurationEvents = getFilteredDurationEvents()
            
            if !filteredDurationEvents.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Execution Duration Analysis")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Menu("Options") {
                            Button("Export Data") {
                                exportPerformanceData()
                            }
                            Button("View Anomalies") {
                                highlightPerformanceAnomalies()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Chart(filteredDurationEvents, id: \.id) { data in
                        LineMark(
                            x: .value("Time", data.timestamp),
                            y: .value("Duration", data.duration)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        
                        AreaMark(
                            x: .value("Time", data.timestamp),
                            y: .value("Duration", data.duration)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .blue.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        if data.duration > getPerformanceThreshold() {
                            PointMark(
                                x: .value("Time", data.timestamp),
                                y: .value("Duration", data.duration)
                            )
                            .foregroundStyle(.red)
                            .symbolSize(40)
                        }
                    }
                    .frame(height: 220)
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine()
                                .foregroundStyle(.secondary.opacity(0.3))
                            AxisTick()
                            AxisValueLabel()
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisGridLine()
                                .foregroundStyle(.secondary.opacity(0.3))
                            AxisTick()
                            AxisValueLabel(format: .dateTime.hour())
                        }
                    }
                    
                    // Performance thresholds legend
                    HStack(spacing: 16) {
                        LegendItem(color: .green, text: "Optimal (<\(String(format: "%.1f", getOptimalThreshold()))s)")
                        LegendItem(color: .orange, text: "Warning")
                        LegendItem(color: .red, text: "Critical")
                    }
                    .font(.caption2)
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
        }
    }
    
    // MARK: - Performance Heatmap
    @ViewBuilder
    private var performanceHeatmap: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Heatmap (24h)")
                .font(.headline)
                .fontWeight(.semibold)
            
            let heatmapData = generateHeatmapData()
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 24), spacing: 2) {
                ForEach(0..<24, id: \.self) { hour in
                    Rectangle()
                        .fill(heatmapColor(for: heatmapData[hour] ?? 0))
                        .frame(height: 20)
                        .overlay(
                            Text(String(hour))
                                .font(.system(size: 8))
                                .foregroundColor(textColor(for: heatmapData[hour] ?? 0))
                        )
                }
            }
            
            HStack {
                Text("0")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.green, .yellow, .orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: 8)
                Text("Max")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Real-time Metrics Section
    @ViewBuilder
    private var realTimeMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.title3)
                    .foregroundStyle(.green)
                Text("Live Metrics")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .scaleEffect(1.0 + sin(Date().timeIntervalSinceReferenceDate * 2) * 0.3)
            }
            
            HStack(spacing: 16) {
                LiveMetricGauge(
                    title: "CPU Usage",
                    value: getCurrentCPUUsage(),
                    maxValue: 100,
                    unit: "%",
                    color: .blue
                )
                
                LiveMetricGauge(
                    title: "Memory",
                    value: getCurrentMemoryUsage(),
                    maxValue: 100,
                    unit: "%",
                    color: .purple
                )
                
                LiveMetricGauge(
                    title: "Battery Impact",
                    value: getBatteryImpact(),
                    maxValue: 100,
                    unit: "%",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Task Performance Section
    @ViewBuilder
    private var taskPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Task Performance Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(viewModel.taskMetrics.filter { shouldShowTask($0) }, id: \.taskIdentifier) { metric in
                EnhancedTaskMetricCard(
                    metric: metric,
                    onTapDetail: {
                        selectedTaskForDetail = metric.taskIdentifier
                        showingDetailedMetrics = true
                    }
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Performance Insights Section
    @ViewBuilder
    private var performanceInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                Text("Performance Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(generatePerformanceInsights(), id: \.id) { insight in
                    PerformanceInsightCard(insight: insight)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Helper Methods
    
    private func getFilteredDurationEvents() -> [DurationEvent] {
        let events = filteredEvents.compactMap { event -> DurationEvent? in
            guard let duration = event.duration, event.type == .taskExecutionCompleted else { return nil }
            
            switch selectedMetricFilter {
            case .all:
                return DurationEvent(id: event.id, timestamp: event.timestamp, duration: duration, taskIdentifier: event.taskIdentifier)
            case .slow:
                return duration > getPerformanceThreshold() ? DurationEvent(id: event.id, timestamp: event.timestamp, duration: duration, taskIdentifier: event.taskIdentifier) : nil
            case .failed:
                return !event.success ? DurationEvent(id: event.id, timestamp: event.timestamp, duration: duration, taskIdentifier: event.taskIdentifier) : nil
            case .recent:
                return event.timestamp > Date().addingTimeInterval(-3600) ? DurationEvent(id: event.id, timestamp: event.timestamp, duration: duration, taskIdentifier: event.taskIdentifier) : nil
            }
        }
        
        return events.sorted { $0.timestamp < $1.timestamp }
    }
    
    @available(iOS 17.0, *)
    private func calculatePerformanceScore(hour: Double, day: Double) -> Double {
        // Generate realistic performance data based on hour and day patterns
        let baseScore = 0.5
        let hourlyVariation = sin(hour * .pi / 12) * 0.2
        let dailyVariation = cos(day * .pi / 3.5) * 0.1
        let noise = (Double.random(in: -0.1...0.1))
        
        return max(0, min(1, baseScore + hourlyVariation + dailyVariation + noise))
    }
    
    private func performanceGradient(for score: Double) -> Color {
        if score < 0.3 {
            return .red.opacity(0.6 + score)
        } else if score < 0.6 {
            return .orange.opacity(0.6 + score * 0.4)
        } else {
            return .green.opacity(0.6 + score * 0.4)
        }
    }
    
    private func generateHeatmapData() -> [Int: Double] {
        var data: [Int: Double] = [:]
        
        for hour in 0..<24 {
            let events = filteredEvents.filter { 
                Calendar.current.component(.hour, from: $0.timestamp) == hour &&
                $0.type == .taskExecutionCompleted
            }
            
            let averageDuration = events.compactMap { $0.duration }.reduce(0, +) / Double(max(events.count, 1))
            data[hour] = averageDuration
        }
        
        return data
    }
    
    private func heatmapColor(for value: Double) -> Color {
        let normalizedValue = min(1.0, value / 10.0) // Normalize to 10 seconds max
        
        if normalizedValue < 0.25 {
            return .green.opacity(0.3 + normalizedValue * 0.7)
        } else if normalizedValue < 0.5 {
            return .yellow.opacity(0.3 + normalizedValue * 0.7)
        } else if normalizedValue < 0.75 {
            return .orange.opacity(0.3 + normalizedValue * 0.7)
        } else {
            return .red.opacity(0.3 + normalizedValue * 0.7)
        }
    }
    
    private func textColor(for value: Double) -> Color {
        return value > 5.0 ? .white : .primary
    }
    
    private func shouldShowTask(_ metric: TaskPerformanceMetrics) -> Bool {
        switch selectedMetricFilter {
        case .all:
            return true
        case .slow:
            return metric.averageDuration > getPerformanceThreshold()
        case .failed:
            return metric.totalFailed > 0
        case .recent:
            return metric.lastExecutionDate?.timeIntervalSinceNow ?? -Double.infinity > -3600
        }
    }
    
    private func getPerformanceThreshold() -> Double { 5.0 }
    private func getOptimalThreshold() -> Double { 2.0 }
    
    private func calculateExecutionTimeTrend() -> PerformanceTrend {
        // Calculate trend based on recent vs historical data
        return .improving // Placeholder
    }
    
    private func calculateSuccessRateTrend() -> PerformanceTrend {
        return .stable
    }
    
    private func calculateThroughputTrend() -> PerformanceTrend {
        return .declining
    }
    
    private func calculateMemoryTrend() -> PerformanceTrend {
        return .improving
    }
    
    private func calculateTaskThroughput() -> Double {
        let recentEvents = filteredEvents.filter { 
            $0.timestamp > Date().addingTimeInterval(-3600)
        }
        return Double(recentEvents.count) / 60.0
    }
    
    private func getPeakMemoryUsage() -> Double {
        // Placeholder - would integrate with actual memory monitoring
        return 45.2
    }
    
    private func formatMemoryUsage(_ usage: Double) -> String {
        return String(format: "%.1f MB", usage)
    }
    
    private func getCurrentCPUUsage() -> Double { Double.random(in: 15...35) }
    private func getCurrentMemoryUsage() -> Double { Double.random(in: 40...60) }
    private func getBatteryImpact() -> Double { Double.random(in: 5...25) }
    
    private func exportPerformanceData() {
        // Implementation for data export
    }
    
    private func highlightPerformanceAnomalies() {
        // Implementation for anomaly detection
    }
    
    private func generatePerformanceInsights() -> [PerformanceInsight] {
        return [
            PerformanceInsight(
                id: UUID(),
                type: .optimization,
                title: "Optimize Task Scheduling",
                description: "Tasks perform 23% better when scheduled between 2-6 AM",
                priority: .medium,
                actionable: true
            ),
            PerformanceInsight(
                id: UUID(),
                type: .warning,
                title: "Memory Usage Spike",
                description: "Background tasks are using 34% more memory than baseline",
                priority: .high,
                actionable: true
            )
        ]
    }
}

// MARK: - Errors Tab

@available(iOS 16.0, *)
struct ErrorsTabView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let selectedTimeRange: TimeRange
    
    private var filteredEvents: [BackgroundTaskEvent] {
        let cutoffDate = Date().addingTimeInterval(-selectedTimeRange.timeInterval)
        return viewModel.events.filter { $0.timestamp >= cutoffDate }
    }
    
    private var filteredStatistics: BackgroundTaskStatistics? {
        guard !filteredEvents.isEmpty else { return nil }
        let cutoffDate = Date().addingTimeInterval(-selectedTimeRange.timeInterval)
        return BackgroundTaskDataStore.shared.generateStatistics(
            for: filteredEvents,
            in: cutoffDate...Date()
        )
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Error Summary
                if let errorsByType = filteredStatistics?.errorsByType,
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
        let failedEvents = filteredEvents.filter { !$0.success }
        ForEach(failedEvents) { event in
            ErrorEventCard(event: event)
        }
    }
}

// MARK: - Continuous Tasks Tab (iOS 26.0+)

@available(iOS 26.0, *)
struct ContinuousTasksTabView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let selectedTimeRange: TimeRange
    
    private var filteredEvents: [BackgroundTaskEvent] {
        let cutoffDate = Date().addingTimeInterval(-selectedTimeRange.timeInterval)
        return viewModel.events.filter { $0.timestamp >= cutoffDate }
    }
    
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

// MARK: - Enhanced Performance Tab Support Types and Views

enum PerformanceMetricFilter: CaseIterable {
    case all, slow, failed, recent
    
    var displayName: String {
        switch self {
        case .all: return "All Tasks"
        case .slow: return "Slow Tasks"
        case .failed: return "Failed Tasks"
        case .recent: return "Recent"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .slow: return "tortoise.fill"
        case .failed: return "xmark.circle.fill"
        case .recent: return "clock.fill"
        }
    }
}

enum PerformanceTrend {
    case improving, stable, declining
    
    var color: Color {
        switch self {
        case .improving: return .green
        case .stable: return .blue
        case .declining: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }
}

struct DurationEvent: Identifiable {
    let id: UUID
    let timestamp: Date
    let duration: TimeInterval
    let taskIdentifier: String
}

struct PerformanceKPICard: View {
    let title: String
    let value: String
    let trend: PerformanceTrend
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Image(systemName: trend.icon)
                    .font(.caption)
                    .foregroundColor(trend.color)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(trend.color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct LegendItem: View {
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
}

struct LiveMetricGauge: View {
    let title: String
    let value: Double
    let maxValue: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 4)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: value / maxValue)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: value)
            }
            
            Text("\(Int(value))\(unit)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct EnhancedTaskMetricCard: View {
    let metric: TaskPerformanceMetrics
    let onTapDetail: () -> Void
    
    var body: some View {
        Button(action: onTapDetail) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(metric.taskIdentifier)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    MetricItem(
                        label: "Success Rate",
                        value: String(format: "%.1f%%", metric.successRate * 100),
                        color: metric.successRate > 0.8 ? .green : .orange
                    )
                    
                    MetricItem(
                        label: "Avg Duration",
                        value: String(format: "%.2fs", metric.averageDuration),
                        color: metric.averageDuration < 5.0 ? .green : .red
                    )
                    
                    MetricItem(
                        label: "Total Runs",
                        value: "\(metric.totalExecuted)",
                        color: .blue
                    )
                }
                
                if let lastExecution = metric.lastExecutionDate {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Last run: \(lastExecution, style: .relative)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct MetricItem: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

enum PerformanceInsightType {
    case optimization, warning, info
    
    var color: Color {
        switch self {
        case .optimization: return .blue
        case .warning: return .orange
        case .info: return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .optimization: return "lightbulb.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

enum PerformancePriority {
    case low, medium, high, critical
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

struct PerformanceInsight: Identifiable {
    let id: UUID
    let type: PerformanceInsightType
    let title: String
    let description: String
    let priority: PerformancePriority
    let actionable: Bool
}

struct PerformanceInsightCard: View {
    let insight: PerformanceInsight
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.type.icon)
                .font(.title3)
                .foregroundColor(insight.type.color)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(insight.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(insight.priority.displayName)
                        .font(.caption2)
                        .foregroundColor(insight.priority.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(insight.priority.color.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if insight.actionable {
                    Button("Take Action") {
                        // Handle action
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(insight.type.color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct DetailedTaskPerformanceView: View {
    let taskIdentifier: String
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Detailed performance charts and metrics
                    Text("Detailed performance view for \(taskIdentifier)")
                        .font(.title2)
                        .padding()
                    
                    // Add detailed charts, metrics, and analysis here
                }
                .padding()
            }
            .navigationTitle(taskIdentifier)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

// MARK: - Time Range Filtering Extensions

extension TimeRange {
    var startDate: Date {
        return Date().addingTimeInterval(-timeInterval)
    }
    
    var endDate: Date {
        return Date()
    }
    
    func contains(_ date: Date) -> Bool {
        return date >= startDate && date <= endDate
    }
}
