//
//  TimelineComponents.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import SwiftUI

// MARK: - Timeline Row View

@available(iOS 16.0, *)
struct TimelineRowView: View {
    let dataPoint: TimelineDataPoint
    let isLast: Bool
    
    init(dataPoint: TimelineDataPoint, isLast: Bool = false) {
        self.dataPoint = dataPoint
        self.isLast = isLast
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack {
                Circle()
                    .fill(dataPoint.success ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                if !isLast {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 20)
                }
            }
            
            // Event details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    TaskIdentifierText(dataPoint.taskIdentifier, font: .caption, maxLines: 3, alwaysExpanded: true)
                    
                    Spacer()
                    
                    Text(dataPoint.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(dataPoint.eventType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let duration = dataPoint.duration {
                    Text(String(format: "Duration: %.2fs", duration))
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Task Identifier Text Component

/// A view that displays task identifiers with full expansion by default and smart wrapping
struct TaskIdentifierText: View {
    let taskIdentifier: String
    let font: Font
    let maxLines: Int?
    let showFullInTooltip: Bool
    let alwaysExpanded: Bool
    @State private var isExpanded = false
    
    init(_ taskIdentifier: String, font: Font = .caption, maxLines: Int? = 3, showFullInTooltip: Bool = true, alwaysExpanded: Bool = false) {
        self.taskIdentifier = taskIdentifier
        self.font = font
        self.maxLines = maxLines
        self.showFullInTooltip = showFullInTooltip
        self.alwaysExpanded = alwaysExpanded
    }
    
    var body: some View {
        if alwaysExpanded {
            // Always show full identifier with wrapping
            Text(taskIdentifier)
                .font(font)
                .fontWeight(.medium)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = taskIdentifier
                    }) {
                        Label("Copy Identifier", systemImage: "doc.on.doc")
                    }
                }
                .help(taskIdentifier)
        } else if showFullInTooltip && taskIdentifier.count > 35 {
            // For very long identifiers, show expandable with context menu
            Text(isExpanded ? taskIdentifier : truncatedIdentifier)
                .font(font)
                .fontWeight(.medium)
                .lineLimit(isExpanded ? nil : maxLines)
                .multilineTextAlignment(.leading)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
                .contextMenu {
                    Button(action: {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }) {
                        Label(isExpanded ? "Collapse" : "Expand", 
                              systemImage: isExpanded ? "arrow.up.circle" : "arrow.down.circle")
                    }
                    
                    Button(action: {
                        UIPasteboard.general.string = taskIdentifier
                    }) {
                        Label("Copy Identifier", systemImage: "doc.on.doc")
                    }
                }
                .help(taskIdentifier) // macOS tooltip
        } else {
            // For shorter identifiers, show fully with limited lines
            Text(taskIdentifier)
                .font(font)
                .fontWeight(.medium)
                .lineLimit(maxLines)
                .multilineTextAlignment(.leading)
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = taskIdentifier
                    }) {
                        Label("Copy Identifier", systemImage: "doc.on.doc")
                    }
                }
                .help(taskIdentifier)
        }
    }
    
    private var truncatedIdentifier: String {
        if taskIdentifier.count <= 35 {
            return taskIdentifier
        }
        
        // More generous truncation - try to keep meaningful parts visible
        let components = taskIdentifier.components(separatedBy: ".")
        if components.count > 1 {
            let firstPart = components.first ?? ""
            let lastPart = components.last ?? ""
            let maxFirstLength = 18  // Increased from 12
            let maxLastLength = 15   // Increased from 10
            
            let truncatedFirst = firstPart.count > maxFirstLength ? 
                String(firstPart.prefix(maxFirstLength)) + "..." : firstPart
            let truncatedLast = lastPart.count > maxLastLength ?
                "..." + String(lastPart.suffix(maxLastLength)) : lastPart
            
            return "\(truncatedFirst).\(truncatedLast)"
        } else {
            // Fallback to simple truncation - more generous
            return String(taskIdentifier.prefix(32)) + "..."
        }
    }
}

/// A compact view for displaying task identifiers in lists
struct CompactTaskIdentifierRow: View {
    let taskIdentifier: String
    let subtitle: String?
    let trailingContent: (() -> AnyView)?
    
    init(_ taskIdentifier: String, subtitle: String? = nil, @ViewBuilder trailingContent: @escaping () -> some View = { EmptyView() }) {
        self.taskIdentifier = taskIdentifier
        self.subtitle = subtitle
        self.trailingContent = { AnyView(trailingContent()) }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                TaskIdentifierText(taskIdentifier, font: .subheadline, maxLines: 3, alwaysExpanded: true)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 8)
            
            trailingContent?()
        }
        .padding(.vertical, 4)
    }
}