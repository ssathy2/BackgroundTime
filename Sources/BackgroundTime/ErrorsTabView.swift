//
//  ErrorsTabView.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import SwiftUI
import Charts

// MARK: - Errors Tab

@available(iOS 16.0, *)
public struct ErrorsTabView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let selectedTimeRange: TimeRange
    
    public init(viewModel: DashboardViewModel, selectedTimeRange: TimeRange) {
        self.viewModel = viewModel
        self.selectedTimeRange = selectedTimeRange
    }
    
    private var filteredEvents: [BackgroundTaskEvent] {
        return viewModel.events.filter { event in
            selectedTimeRange.contains(event.timestamp)
        }
    }
    
    private var filteredStatistics: BackgroundTaskStatistics? {
        guard !filteredEvents.isEmpty else { return nil }
        
        return BackgroundTaskDataStore.shared.generateStatistics(
            for: filteredEvents,
            in: selectedTimeRange.startDate...selectedTimeRange.endDate
        )
    }
    
    public var body: some View {
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
                await viewModel.refresh()
            }
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

// MARK: - Error Summary Section

public struct ErrorSummarySection: View {
    let errorsByType: [String: Int]

    public init(errorsByType: [String: Int]) {
        self.errorsByType = errorsByType
    }

    private var sortedErrorTypes: [String] {
        let keys = Array(errorsByType.keys)
        return keys.sorted()
    }

    private var chartHeight: CGFloat {
        let minHeight: CGFloat = 200.0
        let itemHeight: CGFloat = 30.0
        let count = errorsByType.count
        let calculatedHeight = CGFloat(count) * itemHeight
        return max(minHeight, calculatedHeight)
    }

    private func errorCount(for errorType: String) -> Int {
        return errorsByType[errorType] ?? 0
    }

    private func truncatedErrorType(_ errorType: String) -> String {
        let prefix = errorType.prefix(30)
        return String(prefix)
    }

    public var body: some View {
        let content = VStack(alignment: .leading, spacing: 12) {
            titleView
            errorChart
        }

        return content
            .background(Color(.systemBackground))
            .cornerRadius(12)
    }

    private var titleView: some View {
        Text("Error Types")
            .font(.headline)
            .padding(.horizontal)
    }

    private var errorChart: some View {
        Chart {
            ForEach(sortedErrorTypes, id: \.self) { errorType in
                let count = errorCount(for: errorType)
                let label = truncatedErrorType(errorType)

                BarMark(
                    x: .value("Count", count),
                    y: .value("Error Type", label)
                )
                .foregroundStyle(.red)
            }
        }
        .frame(height: chartHeight)
        .padding(.horizontal)
    }
}