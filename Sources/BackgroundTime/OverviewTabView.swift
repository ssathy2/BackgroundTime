//
//  OverviewTabView.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import SwiftUI
import Charts

// MARK: - Overview Tab

@available(iOS 16.0, *)
public struct OverviewTabView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let selectedTimeRange: TimeRange
    
    public init(viewModel: DashboardViewModel, selectedTimeRange: TimeRange) {
        self.viewModel = viewModel
        self.selectedTimeRange = selectedTimeRange
    }
    
    private var filteredEvents: [BackgroundTaskEvent] {
        let filtered = viewModel.events.filter { event in
            selectedTimeRange.contains(event.timestamp)
        }
        
        // Debug logging for overview filtering
        if !filtered.isEmpty {
            print("📊 Overview Tab - Filtered Events:")
            print("   - \(selectedTimeRange.debugDescription)")
            print("   - Total events in view model: \(viewModel.events.count)")
            print("   - Filtered events: \(filtered.count)")
            
            // Show sample events for debugging
            for event in filtered.prefix(3) {
                print("   - \(event.type.rawValue): \(event.taskIdentifier), time: \(event.timestamp)")
            }
        }
        
        return filtered
    }
    
    private var filteredStatistics: BackgroundTaskStatistics? {
        guard !filteredEvents.isEmpty else { 
            return nil
        }
        
        let stats = BackgroundTaskDataStore.shared.generateStatistics(
            for: filteredEvents, 
            in: selectedTimeRange.startDate...selectedTimeRange.endDate
        )
        
        print("📊 Overview Tab - Statistics: \(stats.totalTasksExecuted) executed, Success: \(String(format: "%.1f", stats.successRate * 100))%")
        
        return stats
    }
    
    public var body: some View {
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
                await viewModel.refresh()
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