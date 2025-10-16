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
    
    public var body: some View {
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