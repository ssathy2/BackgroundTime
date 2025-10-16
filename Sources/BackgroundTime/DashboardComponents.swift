//
//  DashboardComponents.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import SwiftUI
import Charts

// MARK: - Recent Events View

struct RecentEventsView: View {
    let events: [BackgroundTaskEvent]
    
    init(events: [BackgroundTaskEvent]) {
        self.events = events
    }
    
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
                                TaskIdentifierText(event.taskIdentifier, font: .caption, maxLines: 3, alwaysExpanded: true)
                                
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

// MARK: - Statistic Card

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    init(title: String, value: String, icon: String, color: Color) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
    }
    
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

public struct TaskMetricCard: View {
    let metric: TaskPerformanceMetrics
    
    public init(metric: TaskPerformanceMetrics) {
        self.metric = metric
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TaskIdentifierText(metric.taskIdentifier, font: .headline, maxLines: 3, alwaysExpanded: true)
            
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

public struct MetricRow: View {
    let label: String
    let value: String
    
    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
    
    public var body: some View {
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

public struct ErrorEventCard: View {
    let event: BackgroundTaskEvent
    
    public init(event: BackgroundTaskEvent) {
        self.event = event
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                TaskIdentifierText(event.taskIdentifier, font: .headline, maxLines: 3, alwaysExpanded: true)
                
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
