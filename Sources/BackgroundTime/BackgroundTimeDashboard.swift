//
//  BackgroundTimeDashboard.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import SwiftUI
import Charts
import BackgroundTasks

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
                    
                    AnalysisTabView(viewModel: viewModel, selectedTimeRange: selectedTimeRange)
                        .tabItem {
                            Label("Analysis", systemImage: "lightbulb.fill")
                        }
                        .tag(DashboardTab.analysis)
                    
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
                            await viewModel.refresh()
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
                    await viewModel.loadData(for: selectedTimeRange)
                }
            }
        }
        .onChange(of: selectedTimeRange) { newRange in
            Task { @MainActor in
                await viewModel.loadData(for: newRange)
            }
        }
        .onChange(of: viewModel.error) { newError in
            showingError = newError != nil
        }
    }
    
    private var timeRangePicker: some View {
        VStack(spacing: 8) {
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.shortDisplayName).tag(range)
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
