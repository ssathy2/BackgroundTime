//
//  CircularBufferTests.swift
//  BackgroundTimeTests
//
//  Created by Siddharth Sathyam on 9/25/25.
//

import Testing
import Foundation
@testable import BackgroundTime

// MARK: - Circular Buffer Tests

@Suite("Circular Buffer Tests")
struct CircularBufferTests {
    
    @Test("Buffer initialization and basic operations")
    func testBufferInitialization() async throws {
        let buffer = CircularBuffer<String>(capacity: 3)
        
        #expect(buffer.isEmpty == true)
        #expect(buffer.isFull == false)
        #expect(buffer.currentCount == 0)
        #expect(buffer.availableSpace == 3)
    }
    
    @Test("Buffer append and capacity management")
    func testBufferAppendAndCapacity() async throws {
        let buffer = CircularBuffer<String>(capacity: 3)
        
        // Add elements within capacity
        let dropped1 = buffer.append("first")
        let dropped2 = buffer.append("second")
        let dropped3 = buffer.append("third")
        
        #expect(dropped1 == nil)
        #expect(dropped2 == nil)
        #expect(dropped3 == nil)
        #expect(buffer.isFull == true)
        #expect(buffer.currentCount == 3)
        
        // Add element that exceeds capacity
        let dropped4 = buffer.append("fourth")
        #expect(dropped4 == "first") // Should drop the oldest
        #expect(buffer.currentCount == 3)
        
        let elements = buffer.toArray()
        #expect(elements == ["second", "third", "fourth"])
    }
    
    @Test("Buffer removal operations")
    func testBufferRemoval() async throws {
        let buffer = CircularBuffer<Int>(capacity: 5)
        
        // Add some elements
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        
        // Test removeFirst
        let first = buffer.removeFirst()
        #expect(first == 1)
        #expect(buffer.currentCount == 2)
        
        // Test removeLast
        let last = buffer.removeLast()
        #expect(last == 3)
        #expect(buffer.currentCount == 1)
        
        let remaining = buffer.toArray()
        #expect(remaining == [2])
    }
    
    @Test("Buffer peek operations")
    func testBufferPeek() async throws {
        let buffer = CircularBuffer<String>(capacity: 3)
        
        #expect(buffer.peek() == nil)
        #expect(buffer.peekLast() == nil)
        
        buffer.append("one")
        buffer.append("two")
        buffer.append("three")
        
        #expect(buffer.peek() == "one") // First element
        #expect(buffer.peekLast() == "three") // Last element
        #expect(buffer.currentCount == 3) // Count unchanged
    }
    
    @Test("Buffer subscript access")
    func testBufferSubscript() async throws {
        let buffer = CircularBuffer<String>(capacity: 5)
        
        buffer.append("a")
        buffer.append("b")
        buffer.append("c")
        
        #expect(buffer[0] == "a")
        #expect(buffer[1] == "b")
        #expect(buffer[2] == "c")
        #expect(buffer[3] == nil) // Out of bounds
        #expect(buffer[-1] == nil) // Negative index
    }
    
    @Test("Buffer statistics")
    func testBufferStatistics() async throws {
        let buffer = CircularBuffer<Int>(capacity: 10)
        
        let initialStats = buffer.getStatistics()
        #expect(initialStats.isEmpty == true)
        #expect(initialStats.utilizationPercentage == 0.0)
        
        // Add some elements
        for i in 1...7 {
            buffer.append(i)
        }
        
        let stats = buffer.getStatistics()
        #expect(stats.currentCount == 7)
        #expect(stats.capacity == 10)
        #expect(stats.availableSpace == 3)
        #expect(stats.utilizationPercentage == 70.0)
        #expect(stats.isEmpty == false)
        #expect(stats.isFull == false)
    }
    
    @Test("Buffer resize operations")
    func testBufferResize() async throws {
        let buffer = CircularBuffer<String>(capacity: 5)
        
        // Fill buffer
        for i in 1...7 {
            buffer.append("item\(i)")
        }
        
        let beforeResize = buffer.toArray()
        #expect(beforeResize.count == 5)
        #expect(beforeResize == ["item3", "item4", "item5", "item6", "item7"])
        
        // Resize to smaller capacity - modifies buffer in place
        buffer.resize(to: 3)
        let afterResize = buffer.toArray()
        
        #expect(afterResize.count == 3)
        #expect(buffer.capacity == 3)
        // Should keep the most recent elements
        #expect(afterResize == ["item5", "item6", "item7"])
    }
    
    @Test("Buffer thread safety simulation")
    func testBufferConcurrency() async throws {
        let buffer = CircularBuffer<Int>(capacity: 100)
        
        await withTaskGroup(of: Void.self) { group in
            // Multiple concurrent writes
            for i in 0..<50 {
                group.addTask {
                    buffer.append(i)
                }
            }
            
            // Multiple concurrent reads
            for _ in 0..<20 {
                group.addTask {
                    _ = buffer.toArray()
                    _ = buffer.getStatistics()
                }
            }
        }
        
        // Verify buffer is in a consistent state
        let finalCount = buffer.currentCount
        let finalElements = buffer.toArray()
        
        #expect(finalCount <= 100)
        #expect(finalElements.count == finalCount)
    }
    
    @Test("Buffer with complex types")
    func testBufferWithComplexTypes() async throws {
        struct TestEvent: Codable, Equatable {
            let id: String
            let timestamp: Date
            let data: [String: String]
        }
        
        let buffer = CircularBuffer<TestEvent>(capacity: 3)
        
        let event1 = TestEvent(id: "1", timestamp: Date(), data: ["key": "value1"])
        let event2 = TestEvent(id: "2", timestamp: Date(), data: ["key": "value2"])
        
        buffer.append(event1)
        buffer.append(event2)
        
        let retrieved = buffer.toArray()
        #expect(retrieved.count == 2)
        #expect(retrieved[0].id == "1")
        #expect(retrieved[1].id == "2")
    }
    
    @Test("Buffer functional operations")
    func testBufferFunctionalOperations() async throws {
        let buffer = CircularBuffer<Int>(capacity: 10)
        
        // Add test data
        for i in 1...8 {
            buffer.append(i)
        }
        
        // Test filter
        let evenNumbers = buffer.filter { $0 % 2 == 0 }
        #expect(evenNumbers == [2, 4, 6, 8])
        
        // Test map
        let doubled = buffer.map { $0 * 2 }
        #expect(doubled == [2, 4, 6, 8, 10, 12, 14, 16])
        
        // Test compactMap
        let validNumbers = buffer.compactMap { $0 > 5 ? $0 : nil }
        #expect(validNumbers == [6, 7, 8])
    }
}
