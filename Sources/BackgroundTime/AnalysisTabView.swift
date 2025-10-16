//
//  AnalysisTabView.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import SwiftUI

// MARK: - Analysis Tab

@available(iOS 16.0, *)
public struct AnalysisTabView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let selectedTimeRange: TimeRange
    @State private var schedulingAnalyses: [TaskSchedulingAnalysis] = []
    @State private var selectedAnalysis: TaskSchedulingAnalysis?
    @State private var isLoadingAnalysis = false
    
    public init(viewModel: DashboardViewModel, selectedTimeRange: TimeRange) {
        self.viewModel = viewModel
        self.selectedTimeRange = selectedTimeRange
    }
    
    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if isLoadingAnalysis {
                    ProgressView("Analyzing task scheduling patterns...")
                        .padding()
                } else if schedulingAnalyses.isEmpty {
                    EmptyAnalysisView()
                } else {
                    // Analysis Summary Cards
                    AnalysisSummarySection(analyses: schedulingAnalyses)
                    
                    // Task Analysis List
                    TaskAnalysisListSection(
                        analyses: schedulingAnalyses,
                        selectedAnalysis: $selectedAnalysis
                    )
                    
                    // Top Recommendations
                    TopRecommendationsSection(analyses: schedulingAnalyses)
                }
            }
            .padding()
        }
        .refreshable {
            await loadSchedulingAnalysis()
        }
        .onAppear {
            Task {
                await loadSchedulingAnalysis()
            }
        }
        .sheet(item: $selectedAnalysis) { analysis in
            NavigationView {
                TaskSchedulingAnalysisView(analysis: analysis)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                selectedAnalysis = nil
                            }
                        }
                    }
            }
        }
    }
    
    @MainActor
    private func loadSchedulingAnalysis() async {
        isLoadingAnalysis = true
        defer { isLoadingAnalysis = false }
        
        // Use BackgroundTime to get scheduling analysis
        schedulingAnalyses = BackgroundTime.shared.analyzeAllTaskScheduling()
    }
}

// MARK: - Analysis Tab Components

@available(iOS 16.0, *)
public struct EmptyAnalysisView: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Analysis Available")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Background tasks need to be scheduled and executed to generate analysis data. Check back after your app has run some background tasks.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 32)
    }
}

@available(iOS 16.0, *)
public struct AnalysisSummarySection: View {
    let analyses: [TaskSchedulingAnalysis]
    
    public init(analyses: [TaskSchedulingAnalysis]) {
        self.analyses = analyses
    }
    
    private var summaryStats: (totalTasks: Int, averageDelay: TimeInterval, totalRecommendations: Int) {
        let totalTasks = analyses.reduce(0) { $0 + $1.totalScheduledTasks }
        let averageDelay = analyses.isEmpty ? 0 : analyses.map(\.averageExecutionDelay).reduce(0, +) / Double(analyses.count)
        let totalRecommendations = analyses.reduce(0) { $0 + $1.optimizationRecommendations.count }
        
        return (totalTasks, averageDelay, totalRecommendations)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis Summary")
                .font(.headline)
            
            HStack(spacing: 20) {
                SummaryStatCard(
                    title: "Tasks Analyzed",
                    value: "\(summaryStats.totalTasks)",
                    icon: "calendar.badge.checkmark",
                    color: .blue
                )
                
                SummaryStatCard(
                    title: "Avg Delay",
                    value: formatTimeInterval(summaryStats.averageDelay),
                    icon: "clock",
                    color: .orange
                )
                
                SummaryStatCard(
                    title: "Recommendations",
                    value: "\(summaryStats.totalRecommendations)",
                    icon: "lightbulb.fill",
                    color: .yellow
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

@available(iOS 16.0, *)
public struct SummaryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    public init(title: String, value: String, icon: String, color: Color) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

@available(iOS 16.0, *)
public struct TaskAnalysisListSection: View {
    let analyses: [TaskSchedulingAnalysis]
    @Binding var selectedAnalysis: TaskSchedulingAnalysis?
    
    public init(analyses: [TaskSchedulingAnalysis], selectedAnalysis: Binding<TaskSchedulingAnalysis?>) {
        self.analyses = analyses
        self._selectedAnalysis = selectedAnalysis
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Task Analysis")
                .font(.headline)
            
            ForEach(analyses, id: \.taskIdentifier) { analysis in
                TaskAnalysisRow(analysis: analysis)
                    .onTapGesture {
                        selectedAnalysis = analysis
                    }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

@available(iOS 16.0, *)
public struct TaskAnalysisRow: View {
    let analysis: TaskSchedulingAnalysis
    
    public init(analysis: TaskSchedulingAnalysis) {
        self.analysis = analysis
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    TaskIdentifierText(analysis.taskIdentifier, font: .subheadline, maxLines: 3, alwaysExpanded: true)
                    
                    Text("\(analysis.totalScheduledTasks) scheduled • \(Int(analysis.executionRate * 100))% success")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatTimeInterval(analysis.averageExecutionDelay))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if !analysis.optimizationRecommendations.isEmpty {
                        Label("\(analysis.optimizationRecommendations.count)", systemImage: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

@available(iOS 16.0, *)
public struct TopRecommendationsSection: View {
    let analyses: [TaskSchedulingAnalysis]
    
    public init(analyses: [TaskSchedulingAnalysis]) {
        self.analyses = analyses
    }
    
    private var topRecommendations: [SchedulingRecommendation] {
        let allRecommendations = analyses.flatMap(\.optimizationRecommendations)
        let highPriority = allRecommendations.filter { $0.priority == .high }
        let mediumPriority = allRecommendations.filter { $0.priority == .medium }
        
        return Array((highPriority + mediumPriority).prefix(5))
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Recommendations")
                .font(.headline)
            
            if topRecommendations.isEmpty {
                Text("No optimization recommendations available")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(topRecommendations) { recommendation in
                    CompactRecommendationCard(recommendation: recommendation)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

@available(iOS 16.0, *)
public struct CompactRecommendationCard: View {
    let recommendation: SchedulingRecommendation
    
    public init(recommendation: SchedulingRecommendation) {
        self.recommendation = recommendation
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(recommendation.potentialImprovement)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: recommendation.type.systemImage)
                .font(.caption)
                .foregroundColor(priorityColor)
        }
        .padding(.vertical, 8)
    }
    
    private var priorityColor: Color {
        switch recommendation.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

// MARK: - Helper Extensions

extension RecommendationType {
    public var systemImage: String {
        switch self {
        case .timing: return "clock"
        case .networkRequirement: return "wifi"
        case .powerRequirement: return "battery.100"
        case .frequency: return "repeat"
        case .systemConditions: return "gear"
        }
    }
}
