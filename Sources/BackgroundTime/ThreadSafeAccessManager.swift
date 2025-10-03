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
