//
//  CircularBuffer.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/25/25.
//

import Foundation
import os.log

// MARK: - Thread-Safe Circular Buffer

public class CircularBuffer<T: Codable> {
    private var buffer: [T?]
    private var head: Int = 0
    private var tail: Int = 0
    private var count: Int = 0
    public var capacity: Int
    private let lock = NSLock()
    private let logger = Logger(subsystem: "BackgroundTime", category: "CircularBuffer")
    
    public var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return count == 0
    }
    
    public var isFull: Bool {
        lock.lock()
        defer { lock.unlock() }
        return count == capacity
    }
    
    public var currentCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
    
    public var availableSpace: Int {
        lock.lock()
        defer { lock.unlock() }
        return capacity - count
    }
    
    public init(capacity: Int) {
        precondition(capacity > 0, "Buffer capacity must be greater than 0")
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }
    
    public convenience init(capacity: Int, initialElements: [T]) {
        self.init(capacity: capacity)
        for element in initialElements.prefix(capacity) {
            append(element)
        }
    }
    
    required public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let capacity = try container.decode(Int.self, forKey: .capacity)
        let elements = try container.decode([T].self, forKey: .elements)
        
        self.init(capacity: capacity, initialElements: elements)
    }
    
    // MARK: - Codable Keys
    private enum CodingKeys: String, CodingKey {
        case capacity, elements
    }
    
    // MARK: - Core Operations
    
    @discardableResult
    public func append(_ element: T) -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        var droppedElement: T? = nil
        
        // If buffer is full, we'll overwrite the oldest element
        if count == capacity {
            droppedElement = buffer[tail]
            tail = (tail + 1) % capacity
        } else {
            count += 1
        }
        
        buffer[head] = element
        head = (head + 1) % capacity
        
        if droppedElement != nil {
            logger.debug("Buffer full: dropped oldest element to make room for new element")
        }
        
        return droppedElement
    }
    
    public func append(contentsOf elements: [T]) -> [T] {
        var droppedElements: [T] = []
        for element in elements {
            if let dropped = append(element) {
                droppedElements.append(dropped)
            }
        }
        return droppedElements
    }
    
    public func removeFirst() -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        guard count > 0 else { return nil }
        
        let element = buffer[tail]!
        buffer[tail] = nil
        tail = (tail + 1) % capacity
        count -= 1
        
        return element
    }
    
    public func removeLast() -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        guard count > 0 else { return nil }
        
        head = (head - 1 + capacity) % capacity
        let element = buffer[head]!
        buffer[head] = nil
        count -= 1
        
        return element
    }
    
    // MARK: - Access Operations
    
    public func peek() -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        guard count > 0 else { return nil }
        return buffer[tail]
    }
    
    public func peekLast() -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        guard count > 0 else { return nil }
        let lastIndex = (head - 1 + capacity) % capacity
        return buffer[lastIndex]
    }
    
    public subscript(index: Int) -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        guard index >= 0 && index < count else { return nil }
        let actualIndex = (tail + index) % capacity
        return buffer[actualIndex]
    }
    
    // MARK: - Bulk Operations
    
    public func toArray() -> [T] {
        lock.lock()
        defer { lock.unlock() }
        
        guard count > 0 else { return [] }
        
        var result: [T] = []
        result.reserveCapacity(count)
        
        var current = tail
        for _ in 0..<count {
            if let element = buffer[current] {
                result.append(element)
            }
            current = (current + 1) % capacity
        }
        
        return result
    }
    
    public func forEach(_ body: (T) throws -> Void) rethrows {
        lock.lock()
        let elements = toArrayUnsafe()
        lock.unlock()
        
        for element in elements {
            try body(element)
        }
    }
    
    public func filter(_ isIncluded: (T) throws -> Bool) rethrows -> [T] {
        lock.lock()
        let elements = toArrayUnsafe()
        lock.unlock()
        
        return try elements.filter(isIncluded)
    }
    
    public func map<U>(_ transform: (T) throws -> U) rethrows -> [U] {
        lock.lock()
        let elements = toArrayUnsafe()
        lock.unlock()
        
        return try elements.map(transform)
    }
    
    public func compactMap<U>(_ transform: (T) throws -> U?) rethrows -> [U] {
        lock.lock()
        let elements = toArrayUnsafe()
        lock.unlock()
        
        return try elements.compactMap(transform)
    }
    
    // MARK: - Utility Operations
    
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        // Clear all elements
        for i in 0..<capacity {
            buffer[i] = nil
        }
        
        head = 0
        tail = 0
        count = 0
        logger.debug("Buffer cleared")
    }
    
    public func resize(to newCapacity: Int) {
        precondition(newCapacity > 0, "Buffer capacity must be greater than 0")
        
        lock.lock()
        defer { lock.unlock() }
        
        let elements = toArrayUnsafe()
        
        self.capacity = newCapacity
        self.buffer = Array(repeating: nil, count: newCapacity)
        self.head = 0
        self.tail = 0
        self.count = 0
        
        // Re-add elements up to the new capacity
        let elementsToKeep = elements.suffix(newCapacity)
        for element in elementsToKeep {
            buffer[head] = element
            head = (head + 1) % newCapacity
            count += 1
        }
        
        let droppedCount = elements.count - elementsToKeep.count
        if droppedCount > 0 {
            logger.info("Resized buffer: dropped \(droppedCount) oldest elements")
        }
    }
    
    public func getStatistics() -> BufferStatistics {
        lock.lock()
        defer { lock.unlock() }
        
        return BufferStatistics(
            capacity: capacity,
            currentCount: count,
            availableSpace: capacity - count,
            utilizationPercentage: Double(count) / Double(capacity) * 100,
            isEmpty: count == 0,
            isFull: count == capacity
        )
    }
    
    // MARK: - Private Helpers
    
    private func toArrayUnsafe() -> [T] {
        guard count > 0 else { return [] }
        
        var result: [T] = []
        result.reserveCapacity(count)
        
        var current = tail
        for _ in 0..<count {
            if let element = buffer[current] {
                result.append(element)
            }
            current = (current + 1) % capacity
        }
        
        return result
    }
}

// MARK: - Sequence Conformance

extension CircularBuffer: Sequence {
    public func makeIterator() -> CircularBufferIterator<T> {
        lock.lock()
        let elements = toArrayUnsafe()
        lock.unlock()
        
        return CircularBufferIterator(elements: elements)
    }
}

public struct CircularBufferIterator<T>: IteratorProtocol {
    private let elements: [T]
    private var index = 0
    
    init(elements: [T]) {
        self.elements = elements
    }
    
    public mutating func next() -> T? {
        guard index < elements.count else { return nil }
        defer { index += 1 }
        return elements[index]
    }
}

// MARK: - Codable Support

extension CircularBuffer: Codable where T: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(capacity, forKey: .capacity)
        try container.encode(toArray(), forKey: .elements)
    }
}
