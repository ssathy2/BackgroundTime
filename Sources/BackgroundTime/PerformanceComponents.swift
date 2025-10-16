//
//  PerformanceComponents.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import SwiftUI
import Charts

// MARK: - Performance UI Components

public struct PerformanceKPICard: View {
    let title: String
    let value: String
    let trend: PerformanceTrend
    let icon: String
    
    public init(title: String, value: String, trend: PerformanceTrend, icon: String) {
        self.title = title
        self.value = value
        self.trend = trend
        self.icon = icon
    }
    
    public var body: some View {
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

public struct LegendItem: View {
    let color: Color
    let text: String
    
    public init(color: Color, text: String) {
        self.color = color
        self.text = text
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
}

public struct LiveMetricGauge: View {
    let title: String
    let value: Double
    let maxValue: Double
    let unit: String
    let color: Color
    
    public init(title: String, value: Double, maxValue: Double, unit: String, color: Color) {
        self.title = title
        self.value = value
        self.maxValue = maxValue
        self.unit = unit
        self.color = color
    }
    
    public var body: some View {
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

public struct EnhancedTaskMetricCard: View {
    let metric: TaskPerformanceMetrics
    let onTapDetail: () -> Void
    
    public init(metric: TaskPerformanceMetrics, onTapDetail: @escaping () -> Void) {
        self.metric = metric
        self.onTapDetail = onTapDetail
    }
    
    public var body: some View {
        Button(action: onTapDetail) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TaskIdentifierText(metric.taskIdentifier, font: .headline, maxLines: 3, showFullInTooltip: true, alwaysExpanded: true)
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

public struct MetricItem: View {
    let label: String
    let value: String
    let color: Color
    
    public init(label: String, value: String, color: Color) {
        self.label = label
        self.value = value
        self.color = color
    }
    
    public var body: some View {
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

public struct PerformanceInsightCard: View {
    let insight: PerformanceInsight
    
    public init(insight: PerformanceInsight) {
        self.insight = insight
    }
    
    public var body: some View {
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

public struct DetailedTaskPerformanceView: View {
    let taskIdentifier: String
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    
    public init(taskIdentifier: String, viewModel: DashboardViewModel) {
        self.taskIdentifier = taskIdentifier
        self.viewModel = viewModel
    }
    
    private var truncatedTitle: String {
        return taskIdentifier.count > 20 ? String(taskIdentifier.prefix(17)) + "..." : taskIdentifier
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Detailed performance charts and metrics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Detailed Performance Analysis")
                            .font(.title2)
                        
                        TaskIdentifierText(taskIdentifier, font: .headline, maxLines: nil, showFullInTooltip: true, alwaysExpanded: true)
                            .padding(.horizontal)
                    }
                    
                    // Add detailed charts, metrics, and analysis here
                }
                .padding()
            }
            .navigationTitle(truncatedTitle)
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