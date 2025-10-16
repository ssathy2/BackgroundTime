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
    
    private var truncatedNavigationTitle: String {
        let identifier = analysis.taskIdentifier
        return identifier.count > 25 ? String(identifier.prefix(22)) + "..." : identifier
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Full Task Identifier Header
            TaskIdentifierHeaderView(taskIdentifier: analysis.taskIdentifier)
            
            // Tab Bar - Fixed spacing and padding
            Picker("Analysis Tab", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text("Timing").tag(1)
                Text("Recommendations").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            
            // Content
            Group {
                if selectedTab == 0 {
                    AnalysisOverviewTabView(analysis: analysis)
                } else if selectedTab == 1 {
                    TimingAnalysisTabView(analysis: analysis)
                } else {
                    RecommendationsTabView(recommendations: analysis.optimizationRecommendations)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .navigationTitle(truncatedNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
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
        .background(Color(.systemGroupedBackground))
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
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
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
                    value: "\(formatTimeInterval(min(analysis.minExecutionDelay, analysis.maxExecutionDelay))) / \(formatTimeInterval(max(analysis.minExecutionDelay, analysis.maxExecutionDelay)))"
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
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
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
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
        .background(Color(.systemGroupedBackground))
    }
}

@available(iOS 16.0, *)
private struct OptimalTimeWindowsChart: View {
    let analysis: TaskSchedulingAnalysis
    
    private var timeWindowData: [(String, TimeInterval)] {
        let immediateWindows = analysis.immediateTasksAnalysis.optimalTimeWindows.prefix(3)
        let delayedWindows = analysis.delayedTasksAnalysis.optimalTimeWindows.prefix(3)
        
        let allWindows = Array(immediateWindows) + Array(delayedWindows)
        
        // Sort by average delay and take the best performing windows
        let sortedWindows = allWindows.sorted { $0.averageDelay < $1.averageDelay }
        
        return Array(sortedWindows.prefix(6)).map { window in
            (window.description, window.averageDelay)
        }
    }
    
    private var maxTimeWindowDelay: TimeInterval {
        let maxDelay = timeWindowData.map { $0.1 }.max() ?? 0
        return max(maxDelay * 1.1, 60) // Add 10% padding or minimum 60 seconds
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optimal Time Windows")
                .font(.headline)
                .foregroundColor(.primary)
            
            if timeWindowData.isEmpty {
                Text("No time window data available")
                    .foregroundColor(.secondary)
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(timeWindowData, id: \.0) { item in
                    BarMark(
                        x: .value("Time Window", item.0),
                        y: .value("Average Delay", item.1)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 220) // Increased height for better label visibility
                .padding(.bottom, 20) // Extra padding for rotated labels
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let timeValue = value.as(Double.self) {
                                Text(formatTimeInterval(timeValue))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...maxTimeWindowDelay)
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(anchor: .topLeading) { // Better anchor for rotated text
                            if let stringValue = value.as(String.self) {
                                Text(stringValue)
                                    .font(.caption2)
                                    .rotationEffect(Angle.degrees(-45))
                                    .fixedSize()
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

@available(iOS 16.0, *)
private struct PropertyComparisonChart: View {
    let analysis: TaskSchedulingAnalysis
    
    private var comparisonData: [(String, TimeInterval)] {
        var data: [(String, TimeInterval)] = []
        
        // Always include all categories that have data or meaningful zero values
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
        
        // If we only have one data point, add context by showing zero values for comparison
        if data.count == 1 {
            if analysis.immediateTasksAnalysis.taskCount > 0 && analysis.delayedTasksAnalysis.taskCount == 0 {
                data.append(("Delayed", 0.0))
            } else if analysis.delayedTasksAnalysis.taskCount > 0 && analysis.immediateTasksAnalysis.taskCount == 0 {
                data.append(("Immediate", 0.0))
            }
        }
        
        return data
    }
    
    private var maxDelayValue: TimeInterval {
        let maxDelay = comparisonData.map { $0.1 }.max() ?? 0
        return max(maxDelay * 1.1, 60) // Add 10% padding or minimum 60 seconds
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Property Impact Comparison")
                .font(.headline)
                .foregroundColor(.primary)
            
            if comparisonData.isEmpty {
                Text("No property data available")
                    .foregroundColor(.secondary)
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(comparisonData, id: \.0) { item in
                    BarMark(
                        x: .value("Property", item.0),
                        y: .value("Average Delay", item.1)
                    )
                    .foregroundStyle(colorForProperty(item.0))
                }
                .frame(height: 220) // Increased height for better label visibility
                .padding(.horizontal, 8) // Extra horizontal padding
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let timeValue = value.as(Double.self) {
                                Text(formatTimeInterval(timeValue))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let stringValue = value.as(String.self) {
                                Text(stringValue)
                                    .font(.caption)
                                    .fixedSize()
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...maxDelayValue)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
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
            LazyVStack(alignment: .leading, spacing: 16) {
                if recommendations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "lightbulb")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No optimization recommendations available.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    ForEach(recommendations) { recommendation in
                        RecommendationCard(recommendation: recommendation)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

@available(iOS 16.0, *)
private struct RecommendationCard: View {
    let recommendation: SchedulingRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(recommendation.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                PriorityBadge(priority: recommendation.priority)
            }
            
            Text(recommendation.description)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.green)
                        .frame(width: 16, alignment: .leading)
                    Text(recommendation.potentialImprovement)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "hammer.fill")
                        .foregroundColor(.blue)
                        .frame(width: 16, alignment: .leading)
                    Text(recommendation.implementation)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
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
// MARK: - Convenience View for Multiple Tasks

@available(iOS 16.0, *)
public struct TaskSchedulingOverviewView: View {
    private let analyses: [TaskSchedulingAnalysis]
    @State private var selectedTask: TaskSchedulingAnalysis?
    
    public init(analyses: [TaskSchedulingAnalysis]) {
        self.analyses = analyses
    }
    
    public var body: some View {
        List {
            if analyses.isEmpty {
                Text("No task scheduling data available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(analyses, id: \.taskIdentifier) { analysis in
                    TaskSummaryRow(analysis: analysis)
                        .contentShape(Rectangle()) // Makes entire row tappable
                        .onTapGesture {
                            selectedTask = analysis
                        }
                }
            }
        }
        .navigationTitle("Task Scheduling Analysis")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: Binding<TaskSchedulingAnalysis?>(
            get: { selectedTask },
            set: { selectedTask = $0 }
        )) { analysis in
            NavigationView {
                TaskSchedulingAnalysisView(analysis: analysis)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                selectedTask = nil
                            }
                        }
                    }
            }
        }
    }
}

@available(iOS 16.0, *)
private struct TaskSummaryRow: View {
    let analysis: TaskSchedulingAnalysis
    @State private var showingCopyAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(analysis.taskIdentifier)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)  // Increased from 2 to show more of the identifier
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = analysis.taskIdentifier
                            showingCopyAlert = true
                        }) {
                            Label("Copy Identifier", systemImage: "doc.on.doc")
                        }
                    }
                
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
        .padding(.vertical, 8)
        .alert("Copied", isPresented: $showingCopyAlert) {
            Button("OK") { }
        } message: {
            Text("Task identifier copied to clipboard")
        }
    }
}

// MARK: - Task Identifier Header View

@available(iOS 16.0, *)
private struct TaskIdentifierHeaderView: View {
    let taskIdentifier: String
    @State private var showingCopyAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Task Identifier")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(taskIdentifier)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = taskIdentifier
                                showingCopyAlert = true
                            }) {
                                Label("Copy Identifier", systemImage: "doc.on.doc")
                            }
                        }
                }
                
                Spacer()
                
                Button(action: {
                    UIPasteboard.general.string = taskIdentifier
                    showingCopyAlert = true
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.body)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemGroupedBackground))
        .alert("Copied", isPresented: $showingCopyAlert) {
            Button("OK") { }
        } message: {
            Text("Task identifier copied to clipboard")
        }
    }
}
