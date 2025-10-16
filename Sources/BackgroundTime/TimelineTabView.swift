//
//  TimelineTabView.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import SwiftUI

// MARK: - Timeline Tab

@available(iOS 16.0, *)
struct TimelineTabView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let selectedTimeRange: TimeRange
    
    init(viewModel: DashboardViewModel, selectedTimeRange: TimeRange) {
        self.viewModel = viewModel
        self.selectedTimeRange = selectedTimeRange
    }
    
    private var filteredTimelineData: [TimelineDataPoint] {
        return viewModel.timelineData.filter { dataPoint in
            selectedTimeRange.contains(dataPoint.timestamp)
        }
    }
    
    // Group timeline data by date
    private var groupedTimelineData: [(Date, [TimelineDataPoint])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTimelineData) { dataPoint in
            calendar.startOfDay(for: dataPoint.timestamp)
        }
        
        // Sort by date (newest first)
        return grouped.sorted { $0.key > $1.key }.map { (key, value) in
            // Sort events within each day by timestamp (newest first)
            let sortedEvents = value.sorted { $0.timestamp > $1.timestamp }
            return (key, sortedEvents)
        }
    }
    
    var body: some View {
        ScrollView {
            if groupedTimelineData.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No events found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Try selecting a different time range or wait for background tasks to execute.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
                .padding()
            } else {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(Array(groupedTimelineData.enumerated()), id: \.element.0) { dayIndex, dayData in
                        let (date, events) = dayData
                        
                        Section {
                            // Events for this date
                            LazyVStack(spacing: 8) {
                                ForEach(Array(events.enumerated()), id: \.element.id) { eventIndex, dataPoint in
                                    TimelineRowView(
                                        dataPoint: dataPoint,
                                        isLast: eventIndex == events.count - 1 && dayIndex == groupedTimelineData.count - 1
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                        } header: {
                            // Floating date section header
                            FloatingTimelineDateSectionHeader(date: date)
                        }
                    }
                }
            }
        }
        .refreshable {
            Task { @MainActor in
                await viewModel.refresh()
            }
        }
    }
}

// MARK: - Timeline Date Section Header

@available(iOS 16.0, *)
struct TimelineDateSectionHeader: View {
    let date: Date
    
    init(date: Date) {
        self.date = date
    }
    
    private var dateFormatter: DateFormatter {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return todayFormatter
        } else if calendar.isDateInYesterday(date) {
            return yesterdayFormatter  
        } else if calendar.dateInterval(of: .weekOfYear, for: Date())?.contains(date) == true {
            return weekdayFormatter
        } else {
            return fullDateFormatter
        }
    }
    
    private var todayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "'Today'"
        return formatter
    }
    
    private var yesterdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "'Yesterday'"
        return formatter
    }
    
    private var weekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // Full weekday name
        return formatter
    }
    
    private var fullDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    private var eventCountText: String {
        // This would need to be passed from the parent view
        // For now, we'll just show the date
        return ""
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dateFormatter.string(from: date))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Optional: Add event count or other metadata
                if Calendar.current.isDateInToday(date) {
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            
            // Subtle divider line
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 0.5)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }
}

// MARK: - Floating Timeline Date Section Header

@available(iOS 16.0, *)
struct FloatingTimelineDateSectionHeader: View {
    let date: Date
    
    init(date: Date) {
        self.date = date
    }
    
    private var dateFormatter: DateFormatter {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return todayFormatter
        } else if calendar.isDateInYesterday(date) {
            return yesterdayFormatter  
        } else if calendar.dateInterval(of: .weekOfYear, for: Date())?.contains(date) == true {
            return weekdayFormatter
        } else {
            return fullDateFormatter
        }
    }
    
    private var todayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "'Today'"
        return formatter
    }
    
    private var yesterdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "'Yesterday'"
        return formatter
    }
    
    private var weekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // Full weekday name
        return formatter
    }
    
    private var fullDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(dateFormatter.string(from: date))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Optional: Add event count or other metadata
                if Calendar.current.isDateInToday(date) {
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background {
                // Floating header background with blur effect
                Rectangle()
                    .fill(.regularMaterial)
                    .ignoresSafeArea(edges: .horizontal)
            }
            
            // Bottom divider that spans full width
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 0.5)
                .ignoresSafeArea(edges: .horizontal)
        }
    }
}