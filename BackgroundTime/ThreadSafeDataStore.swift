//
//  ThreadSafeDataStore.swift
//  BackgroundTime
//
//  Created on 9/25/25.
//

import Foundation

/// A thread-safe data store implementation using a circular buffer
public class ThreadSafeDataStore<T: Codable> {
    private var buffer: [T?]
    private var head: Int = 0
    private var tail: Int = 0
    private var _count: Int = 0
    private var _capacity: Int
    private let queue = DispatchQueue(label: "ThreadSafeDataStore", attributes: .concurrent)
    
    public init(capacity: Int) {
        self._capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }
    
    /// Append an element to the store, returns the dropped element if capacity is exceeded
    @discardableResult
    public func append(_ element: T) -> T? {
        return queue.sync(flags: .barrier) {
            var droppedElement: T? = nil
            
            if _count == _capacity {
                // Buffer is full, drop the oldest element
                droppedElement = buffer[head]
                head = (head + 1) % _capacity
            } else {
                _count += 1
            }
            
            buffer[tail] = element
            tail = (tail + 1) % _capacity
            
            return droppedElement
        }
    }
    
    /// Append multiple elements
    public func append<S: Sequence>(contentsOf sequence: S) where S.Element == T {
        for element in sequence {
            append(element)
        }
    }
    
    /// Get all elements as an array
    public func toArray() -> [T] {
        return queue.sync {
            var result: [T] = []
            result.reserveCapacity(_count)
            
            var index = head
            for _ in 0..<_count {
                if let element = buffer[index] {
                    result.append(element)
                }
                index = (index + 1) % _capacity
            }
            
            return result
        }
    }
    
    /// Filter elements
    public func filter(_ predicate: (T) throws -> Bool) rethrows -> [T] {
        return try queue.sync {
            var result: [T] = []
            
            var index = head
            for _ in 0..<_count {
                if let element = buffer[index], try predicate(element) {
                    result.append(element)
                }
                index = (index + 1) % _capacity
            }
            
            return result
        }
    }
    
    /// Perform a batch read operation
    public func performBatchRead<U>(_ operation: ([T]) throws -> U) rethrows -> U {
        return try queue.sync {
            let array = toArray()
            return try operation(array)
        }
    }
    
    /// Get the first element without removing it
    public func peek() -> T? {
        return queue.sync {
            guard _count > 0 else { return nil }
            return buffer[head]
        }
    }
    
    /// Clear all elements
    public func clear() {
        queue.sync(flags: .barrier) {
            head = 0
            tail = 0
            _count = 0
            buffer = Array(repeating: nil, count: _capacity)
        }
    }
    
    /// Resize the buffer
    public func resize(to newCapacity: Int) {
        queue.sync(flags: .barrier) {
            guard newCapacity != _capacity else { return }
            
            // Extract current elements directly without calling toArray()
            var currentElements: [T] = []
            currentElements.reserveCapacity(_count)
            
            var index = head
            for _ in 0..<_count {
                if let element = buffer[index] {
                    currentElements.append(element)
                }
                index = (index + 1) % _capacity
            }
            
            // Update capacity and create new buffer
            self._capacity = newCapacity
            self.buffer = Array(repeating: nil, count: newCapacity)
            self.head = 0
            self.tail = 0
            self._count = 0
            
            // Re-add elements up to the new capacity directly
            let elementsToKeep = currentElements.suffix(newCapacity)
            for element in elementsToKeep {
                // Add element directly without calling append() to avoid deadlock
                buffer[tail] = element
                tail = (tail + 1) % newCapacity
                _count += 1
            }
        }
    }
    
    /// Get current statistics
    public func getStatistics() -> BufferStatistics {
        return queue.sync {
            return BufferStatistics(
                capacity: _capacity,
                currentCount: _count,
                availableSpace: _capacity - _count,
                utilizationPercentage: Double(_count) / Double(_capacity) * 100,
                isEmpty: _count == 0,
                isFull: _count == _capacity
            )
        }
    }
    
    // MARK: - Properties
    
    public var isEmpty: Bool {
        return queue.sync { self._count == 0 }
    }
    
    public var count: Int {
        return queue.sync { self._count }
    }
    
    public var currentCount: Int {
        return queue.sync { self._count }
    }
    
    public var currentCapacity: Int {
        return self._capacity
    }
    
    public var capacity: Int {
        return self._capacity
    }
}

// MARK: - AccessPatternMonitor (Simple Implementation)

public class AccessPatternMonitor {
    public static let shared = AccessPatternMonitor()
    
    private var accessTimes: [String: [TimeInterval]] = [:]
    private let queue = DispatchQueue(label: "AccessPatternMonitor", attributes: .concurrent)
    
    private init() {}
    
    public func recordAccess(operation: String, duration: TimeInterval) {
        queue.sync(flags: .barrier) {
            if accessTimes[operation] == nil {
                accessTimes[operation] = []
            }
            accessTimes[operation]?.append(duration)
        }
    }
    
    public func getPerformanceReport() -> PerformanceReport {
        return queue.sync {
            var operationStats: [String: OperationStats] = [:]
            
            for (operation, times) in accessTimes {
                let averageTime = times.reduce(0, +) / Double(times.count)
                let maxTime = times.max() ?? 0
                let minTime = times.min() ?? 0
                
                operationStats[operation] = OperationStats(
                    averageDuration: averageTime,
                    maxDuration: maxTime,
                    minDuration: minTime,
                    operationCount: times.count
                )
            }
            
            return PerformanceReport(operationStats: operationStats)
        }
    }
}

public struct PerformanceReport {
    public let operationStats: [String: OperationStats]
    
    public init(operationStats: [String: OperationStats]) {
        self.operationStats = operationStats
    }
}

public struct OperationStats {
    public let averageDuration: TimeInterval
    public let maxDuration: TimeInterval
    public let minDuration: TimeInterval
    public let operationCount: Int
    
    public init(averageDuration: TimeInterval, maxDuration: TimeInterval, minDuration: TimeInterval, operationCount: Int) {
        self.averageDuration = averageDuration
        self.maxDuration = maxDuration
        self.minDuration = minDuration
        self.operationCount = operationCount
    }
}
