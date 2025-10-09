//
//  TaskSchedulingAnalysisView.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 10/8/25.
//

import SwiftUI
import Charts

// MARK: - Task Scheduling Analysis View

@available(iOS 16.0, *)
public struct TaskSchedulingAnalysisView: View {
    private let analysis: TaskSchedulingAnalysis
    @State private var selectedTab = 0
    
    public init(analysis: TaskSchedulingAnalysis) {
        self.analysis = analysis
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Bar
                Picker("Analysis Tab", selection: $selectedTab) {
                    Text("Overview").tag(0)
                    Text("Timing").tag(1)
                    Text("Recommendations").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                TabView(selection: $selectedTab) {
                    AnalysisOverviewTabView(analysis: analysis)
                        .tag(0)
                    
                    TimingAnalysisTabView(analysis: analysis)
                        .tag(1)
                    
                    RecommendationsTabView(recommendations: analysis.optimizationRecommendations)
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Task: \(analysis.taskIdentifier)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Overview Tab

@available(iOS 16.0, *)
private struct AnalysisOverviewTabView: View {
    let analysis: TaskSchedulingAnalysis
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Execution Summary Card
                ExecutionSummaryCard(analysis: analysis)
                
                // Delay Statistics Card
                DelayStatisticsCard(analysis: analysis)
                
                // Property Impact Summary
                PropertyImpactSummaryCard(analysis: analysis)
            }
            .padding()
        }
    }
}

@available(iOS 16.0, *)
private struct ExecutionSummaryCard: View {
    let analysis: TaskSchedulingAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Execution Summary")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                StatisticView(
                    title: "Scheduled",
                    value: "\(analysis.totalScheduledTasks)",
                    color: .blue
                )
                
                StatisticView(
                    title: "Executed", 
                    value: "\(analysis.totalExecutedTasks)",
                    color: .green
                )
                
                StatisticView(
                    title: "Success Rate",
                    value: "\(Int(analysis.executionRate * 100))%",
                    color: analysis.executionRate > 0.8 ? .green : (analysis.executionRate > 0.5 ? .orange : .red)
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

@available(iOS 16.0, *)
private struct DelayStatisticsCard: View {
    let analysis: TaskSchedulingAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Execution Delay Statistics")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                DelayStatRow(
                    title: "Average Delay",
                    value: formatTimeInterval(analysis.averageExecutionDelay)
                )
                
                DelayStatRow(
                    title: "Median Delay", 
                    value: formatTimeInterval(analysis.medianExecutionDelay)
                )
                
                DelayStatRow(
                    title: "Min/Max Delay",
                    value: "\(formatTimeInterval(analysis.minExecutionDelay)) / \(formatTimeInterval(analysis.maxExecutionDelay))"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

@available(iOS 16.0, *)
private struct DelayStatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

@available(iOS 16.0, *)
private struct PropertyImpactSummaryCard: View {
    let analysis: TaskSchedulingAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Property Impact Summary")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                PropertyImpactRow(
                    title: "Immediate Tasks",
                    count: analysis.immediateTasksAnalysis.taskCount,
                    averageDelay: analysis.immediateTasksAnalysis.averageDelay
                )
                
                PropertyImpactRow(
                    title: "Delayed Tasks",
                    count: analysis.delayedTasksAnalysis.taskCount,
                    averageDelay: analysis.delayedTasksAnalysis.averageDelay
                )
                
                PropertyImpactRow(
                    title: "Network Required",
                    count: analysis.networkRequiredAnalysis.taskCount,
                    averageDelay: analysis.networkRequiredAnalysis.averageDelay
                )
                
                PropertyImpactRow(
                    title: "Power Required",
                    count: analysis.powerRequiredAnalysis.taskCount,
                    averageDelay: analysis.powerRequiredAnalysis.averageDelay
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

@available(iOS 16.0, *)
private struct PropertyImpactRow: View {
    let title: String
    let count: Int
    let averageDelay: TimeInterval
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count) tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatTimeInterval(averageDelay))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Timing Analysis Tab

@available(iOS 16.0, *)
private struct TimingAnalysisTabView: View {
    let analysis: TaskSchedulingAnalysis
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Optimal Time Windows Chart
                if !analysis.immediateTasksAnalysis.optimalTimeWindows.isEmpty || 
                   !analysis.delayedTasksAnalysis.optimalTimeWindows.isEmpty {
                    OptimalTimeWindowsChart(analysis: analysis)
                }
                
                // Comparison Chart
                PropertyComparisonChart(analysis: analysis)
            }
            .padding()
        }
    }
}

@available(iOS 16.0, *)
private struct OptimalTimeWindowsChart: View {
    let analysis: TaskSchedulingAnalysis
    
    private var timeWindowData: [(String, TimeInterval)] {
        let immediateWindows = analysis.immediateTasksAnalysis.optimalTimeWindows.prefix(5)
        let delayedWindows = analysis.delayedTasksAnalysis.optimalTimeWindows.prefix(5)
        
        let allWindows = Array(immediateWindows) + Array(delayedWindows)
        return Array(allWindows.prefix(8)).map { window in
            (window.description, window.averageDelay)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optimal Time Windows")
                .font(.headline)
                .foregroundColor(.primary)
            
            Chart(timeWindowData, id: \.0) { item in
                BarMark(
                    x: .value("Time Window", item.0),
                    y: .value("Average Delay", item.1)
                )
                .foregroundStyle(.blue)
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(format: .byteCount(style: .memory))
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let stringValue = value.as(String.self) {
                            Text(stringValue)
                                .font(.caption2)
                                .rotationEffect(Angle.degrees(-45))
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

@available(iOS 16.0, *)
private struct PropertyComparisonChart: View {
    let analysis: TaskSchedulingAnalysis
    
    private var comparisonData: [(String, TimeInterval)] {
        var data: [(String, TimeInterval)] = []
        
        if analysis.immediateTasksAnalysis.taskCount > 0 {
            data.append(("Immediate", analysis.immediateTasksAnalysis.averageDelay))
        }
        if analysis.delayedTasksAnalysis.taskCount > 0 {
            data.append(("Delayed", analysis.delayedTasksAnalysis.averageDelay))
        }
        if analysis.networkRequiredAnalysis.taskCount > 0 {
            data.append(("Network", analysis.networkRequiredAnalysis.averageDelay))
        }
        if analysis.powerRequiredAnalysis.taskCount > 0 {
            data.append(("Power", analysis.powerRequiredAnalysis.averageDelay))
        }
        
        return data
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Property Impact Comparison")
                .font(.headline)
                .foregroundColor(.primary)
            
            Chart(comparisonData, id: \.0) { item in
                BarMark(
                    x: .value("Property", item.0),
                    y: .value("Average Delay", item.1)
                )
                .foregroundStyle(colorForProperty(item.0))
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func colorForProperty(_ property: String) -> Color {
        switch property {
        case "Immediate": return .green
        case "Delayed": return .blue
        case "Network": return .orange
        case "Power": return .red
        default: return .gray
        }
    }
}

// MARK: - Recommendations Tab

@available(iOS 16.0, *)
private struct RecommendationsTabView: View {
    let recommendations: [SchedulingRecommendation]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if recommendations.isEmpty {
                    Text("No optimization recommendations available.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(recommendations) { recommendation in
                        RecommendationCard(recommendation: recommendation)
                    }
                }
            }
            .padding()
        }
    }
}

@available(iOS 16.0, *)
private struct RecommendationCard: View {
    let recommendation: SchedulingRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(recommendation.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                PriorityBadge(priority: recommendation.priority)
            }
            
            Text(recommendation.description)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.green)
                    Text(recommendation.potentialImprovement)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Image(systemName: "hammer.fill")
                        .foregroundColor(.blue)
                    Text(recommendation.implementation)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

@available(iOS 16.0, *)
private struct PriorityBadge: View {
    let priority: RecommendationPriority
    
    var body: some View {
        Text(priority.displayName)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityColor)
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
    
    private var priorityColor: Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

// MARK: - Helper Views

@available(iOS 16.0, *)
private struct StatisticView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Helper Functions

private func formatTimeInterval(_ interval: TimeInterval) -> String {
    if interval < 60 {
        return String(format: "%.1fs", interval)
    } else if interval < 3600 {
        return String(format: "%.1fm", interval / 60)
    } else {
        return String(format: "%.1fh", interval / 3600)
    }
}

// MARK: - Convenience View for Multiple Tasks

@available(iOS 16.0, *)
public struct TaskSchedulingOverviewView: View {
    private let analyses: [TaskSchedulingAnalysis]
    @State private var selectedTask: TaskSchedulingAnalysis?
    
    public init(analyses: [TaskSchedulingAnalysis]) {
        self.analyses = analyses
    }
    
    public var body: some View {
        NavigationView {
            List {
                if analyses.isEmpty {
                    Text("No task scheduling data available")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(analyses, id: \.taskIdentifier) { analysis in
                        TaskSummaryRow(analysis: analysis)
                            .onTapGesture {
                                selectedTask = analysis
                            }
                    }
                }
            }
            .navigationTitle("Task Scheduling Analysis")
            .sheet(item: Binding<TaskSchedulingAnalysis?>(
                get: { selectedTask },
                set: { selectedTask = $0 }
            )) { analysis in
                TaskSchedulingAnalysisView(analysis: analysis)
            }
        }
    }
}

@available(iOS 16.0, *)
private struct TaskSummaryRow: View {
    let analysis: TaskSchedulingAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(analysis.taskIdentifier)
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(analysis.executionRate * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(analysis.executionRate > 0.8 ? .green : .orange)
            }
            
            HStack {
                Label("\(analysis.totalScheduledTasks) scheduled", systemImage: "calendar.badge.plus")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label("Avg: \(formatTimeInterval(analysis.averageExecutionDelay))", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !analysis.optimizationRecommendations.isEmpty {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("\(analysis.optimizationRecommendations.count) recommendations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}