//
//  ThreadSafeAccessManager.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/25/25.
//

import Foundation
import os.log

// MARK: - Reader-Writer Lock Implementation

public class ReadWriteLock {
    private let concurrent = DispatchQueue(label: "BackgroundTime.ReadWriteLock", attributes: .concurrent)
    private let logger = Logger(subsystem: "BackgroundTime", category: "ReadWriteLock")
    
    public init() {}
    
    @discardableResult
    public func read<T>(_ block: () throws -> T) rethrows -> T {
        return try concurrent.sync {
            return try block()
        }
    }
    
    @discardableResult
    public func write<T>(_ block: () throws -> T) rethrows -> T {
        return try concurrent.sync(flags: .barrier) {
            return try block()
        }
    }
    
    public func asyncRead(_ block: @escaping () -> Void) {
        concurrent.async {
            block()
        }
    }
    
    public func asyncWrite(_ block: @escaping () -> Void) {
        concurrent.async(flags: .barrier) {
            block()
        }
    }
}

// MARK: - Thread-Safe Data Store

public class ThreadSafeDataStore<T: Codable> {
    private var buffer: CircularBuffer<T>
    private let lock = ReadWriteLock()
    private let logger = Logger(subsystem: "BackgroundTime", category: "ThreadSafeDataStore")
    
    public init(capacity: Int) {
        self.buffer = CircularBuffer<T>(capacity: capacity)
    }
    
    // MARK: - Write Operations
    
    @discardableResult
    public func append(_ element: T) -> T? {
        return lock.write {
            let dropped = buffer.append(element)
            if dropped != nil {
                logger.debug("Element dropped due to buffer capacity limit")
            }
            return dropped
        }
    }
    
    public func append(contentsOf elements: [T]) -> [T] {
        return lock.write {
            let dropped = buffer.append(contentsOf: elements)
            if !dropped.isEmpty {
                logger.debug("Dropped \(dropped.count) elements due to buffer capacity limit")
            }
            return dropped
        }
    }
    
    @discardableResult
    public func removeFirst() -> T? {
        return lock.write {
            return buffer.removeFirst()
        }
    }
    
    @discardableResult
    public func removeLast() -> T? {
        return lock.write {
            return buffer.removeLast()
        }
    }
    
    public func clear() {
        lock.write {
            buffer.clear()
        }
    }
    
    public func resize(to newCapacity: Int) {
        lock.write {
            buffer.resize(to: newCapacity)
            logger.info("Buffer resized to capacity: \(newCapacity)")
        }
    }
    
    // MARK: - Read Operations
    
    public func peek() -> T? {
        return lock.read {
            return buffer.peek()
        }
    }
    
    public func peekLast() -> T? {
        return lock.read {
            return buffer.peekLast()
        }
    }
    
    public subscript(index: Int) -> T? {
        return lock.read {
            return buffer[index]
        }
    }
    
    public func toArray() -> [T] {
        return lock.read {
            return buffer.toArray()
        }
    }
    
    public func filter(_ isIncluded: @escaping (T) -> Bool) -> [T] {
        return lock.read {
            return buffer.filter(isIncluded)
        }
    }
    
    public func map<U>(_ transform: @escaping (T) -> U) -> [U] {
        return lock.read {
            return buffer.map(transform)
        }
    }
    
    public func compactMap<U>(_ transform: @escaping (T) -> U?) -> [U] {
        return lock.read {
            return buffer.compactMap(transform)
        }
    }
    
    // MARK: - Properties
    
    public var isEmpty: Bool {
        return lock.read {
            return buffer.isEmpty
        }
    }
    
    public var isFull: Bool {
        return lock.read {
            return buffer.isFull
        }
    }
    
    public var count: Int {
        return lock.read {
            return buffer.currentCount
        }
    }
    
    public var capacity: Int {
        return lock.read {
            return buffer.capacity
        }
    }
    
    public func getStatistics() -> BufferStatistics {
        return lock.read {
            return buffer.getStatistics()
        }
    }
    
    // MARK: - Batch Operations
    
    public func performBatchRead<U>(_ operation: ([T]) -> U) -> U {
        return lock.read {
            let elements = buffer.toArray()
            return operation(elements)
        }
    }
    
    public func performBatchWrite(_ operation: (CircularBuffer<T>) -> CircularBuffer<T>) {
        lock.write {
            buffer = operation(buffer)
        }
    }
    
    // MARK: - Async Operations
    
    public func asyncAppend(_ element: T, completion: @escaping (T?) -> Void = { _ in }) {
        lock.asyncWrite {
            let dropped = self.buffer.append(element)
            DispatchQueue.main.async {
                completion(dropped)
            }
        }
    }
    
    public func asyncToArray(completion: @escaping ([T]) -> Void) {
        lock.asyncRead {
            let elements = self.buffer.toArray()
            DispatchQueue.main.async {
                completion(elements)
            }
        }
    }
    
    public func asyncFilter(_ isIncluded: @escaping (T) -> Bool, completion: @escaping ([T]) -> Void) {
        lock.asyncRead {
            let filtered = self.buffer.filter(isIncluded)
            DispatchQueue.main.async {
                completion(filtered)
            }
        }
    }
}

// MARK: - Sequence Conformance

extension ThreadSafeDataStore: Sequence {
    public func makeIterator() -> IndexingIterator<[T]> {
        let elements = toArray()
        return elements.makeIterator()
    }
}

// MARK: - Metric Collection Support

public extension ThreadSafeDataStore {
    /// Safely collect metrics without blocking other operations
    func collectMetrics<U: Codable>(using collector: (BufferStatistics, [T]) -> U) -> U {
        return lock.read {
            let stats = buffer.getStatistics()
            let elements = buffer.toArray()
            return collector(stats, elements)
        }
    }
    
    /// Perform a safe cleanup operation, removing elements that match criteria
    @discardableResult
    func cleanup(where shouldRemove: @escaping (T) -> Bool) -> Int {
        return lock.write {
            let originalCount = buffer.currentCount
            let elementsToKeep = buffer.filter { !shouldRemove($0) }
            
            buffer.clear()
            
            for element in elementsToKeep {
                buffer.append(element)
            }
            
            let newCount = buffer.currentCount
            let totalRemoved = originalCount - newCount
            logger.info("Cleanup completed: removed \(totalRemoved) elements")
            return totalRemoved
        }
    }
    
    /// Get a snapshot of current data for safe processing
    func getSnapshot() -> DataSnapshot<T> {
        return lock.read {
            DataSnapshot(
                elements: buffer.toArray(),
                statistics: buffer.getStatistics(),
                timestamp: Date()
            )
        }
    }
}

// MARK: - Data Snapshot

public struct DataSnapshot<T: Codable>: Codable {
    public let elements: [T]
    public let statistics: BufferStatistics
    public let timestamp: Date
    
    public var count: Int { elements.count }
    public var isEmpty: Bool { elements.isEmpty }
    
    public func filter(_ isIncluded: (T) -> Bool) -> [T] {
        return elements.filter(isIncluded)
    }
    
    public func map<U>(_ transform: (T) -> U) -> [U] {
        return elements.map(transform)
    }
}

// MARK: - Performance Monitor

public class AccessPatternMonitor {
    private struct AccessMetric: Codable {
        let operation: String
        let duration: TimeInterval
        let timestamp: Date
        let success: Bool
    }
    
    private let metrics = ThreadSafeDataStore<AccessMetric>(capacity: 1000)
    private let logger = Logger(subsystem: "BackgroundTime", category: "AccessPatternMonitor")
    
    public static let shared = AccessPatternMonitor()
    private init() {}
    
    public func recordAccess(operation: String, duration: TimeInterval, success: Bool = true) {
        let metric = AccessMetric(
            operation: operation,
            duration: duration,
            timestamp: Date(),
            success: success
        )
        
        metrics.append(metric)
        
        if duration > 0.1 { // Log slow operations
            logger.warning("Slow operation detected: \(operation) took \(duration)s")
        }
    }
    
    public func getPerformanceReport() -> PerformanceReport {
        return metrics.performBatchRead { accessMetrics in
            let totalOperations = accessMetrics.count
            let averageDuration = accessMetrics.isEmpty ? 0 : 
                accessMetrics.map { $0.duration }.reduce(0, +) / Double(accessMetrics.count)
            
            let operationCounts = Dictionary(grouping: accessMetrics, by: { $0.operation })
                .mapValues { $0.count }
            
            let slowOperations = accessMetrics.filter { $0.duration > 0.1 }.count
            let failedOperations = accessMetrics.filter { !$0.success }.count
            
            return PerformanceReport(
                totalOperations: totalOperations,
                averageDuration: averageDuration,
                slowOperations: slowOperations,
                failedOperations: failedOperations,
                operationBreakdown: operationCounts,
                reportTimestamp: Date()
            )
        }
    }
}

public struct PerformanceReport: Codable {
    public let totalOperations: Int
    public let averageDuration: TimeInterval
    public let slowOperations: Int
    public let failedOperations: Int
    public let operationBreakdown: [String: Int]
    public let reportTimestamp: Date
    
    public var successRate: Double {
        guard totalOperations > 0 else { return 1.0 }
        return Double(totalOperations - failedOperations) / Double(totalOperations)
    }
    
    public var slowOperationPercentage: Double {
        guard totalOperations > 0 else { return 0.0 }
        return Double(slowOperations) / Double(totalOperations) * 100
    }
}
