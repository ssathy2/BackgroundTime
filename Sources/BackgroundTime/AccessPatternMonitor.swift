//
//  AccessPatternMonitor.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/26/25.
//

import Foundation

/// Simple access pattern monitor for tracking data store performance
public final class AccessPatternMonitor: @unchecked Sendable {
    public static let shared = AccessPatternMonitor()
    
    private var accessTimes: [String: [TimeInterval]] = [:]
    private let queue = DispatchQueue(label: "AccessPatternMonitor", attributes: .concurrent)
    
    private init() {}
    
    public func recordAccess(operation: String, duration: TimeInterval) {
        queue.async(flags: .barrier) { [weak self] in
            if self?.accessTimes[operation] == nil {
                self?.accessTimes[operation] = []
            }
            self?.accessTimes[operation]?.append(duration)
        }
    }
    
    public func getPerformanceReport() -> PerformanceReport {
        return queue.sync {
            var operationStats: [String: OperationStats] = [:]
            
            for (operation, times) in accessTimes {
                let totalTime = times.reduce(0, +)
                let avgTime = times.isEmpty ? 0 : totalTime / Double(times.count)
                let maxTime = times.max() ?? 0
                let minTime = times.min() ?? 0
                
                operationStats[operation] = OperationStats(
                    totalCalls: times.count,
                    averageTime: avgTime,
                    totalTime: totalTime,
                    minTime: minTime,
                    maxTime: maxTime
                )
            }
            
            return PerformanceReport(operationStats: operationStats)
        }
    }
}

public struct PerformanceReport: Sendable {
    public let operationStats: [String: OperationStats]
}

public struct OperationStats: Sendable {
    public let totalCalls: Int
    public let averageTime: TimeInterval
    public let totalTime: TimeInterval
    public let minTime: TimeInterval
    public let maxTime: TimeInterval
}

// MARK: - Statistics

public struct BufferStatistics: Codable, Sendable {
    public let capacity: Int
    public let currentCount: Int
    public let availableSpace: Int
    public let utilizationPercentage: Double
    public let isEmpty: Bool
    public let isFull: Bool
    
    public init(capacity: Int, currentCount: Int, availableSpace: Int, utilizationPercentage: Double, isEmpty: Bool, isFull: Bool) {
        self.capacity = capacity
        self.currentCount = currentCount
        self.availableSpace = availableSpace
        self.utilizationPercentage = utilizationPercentage
        self.isEmpty = isEmpty
        self.isFull = isFull
    }
}
