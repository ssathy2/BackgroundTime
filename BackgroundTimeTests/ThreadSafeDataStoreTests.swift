//
//  ThreadSafeDataStoreTests.swift
//  BackgroundTimeTests
//
//  Created by Siddharth Sathyam on 9/25/25.
//

import Testing
import Foundation
@testable import BackgroundTime

// MARK: - Thread-Safe Data Store Tests

@Suite("Thread-Safe Data Store Tests")
struct ThreadSafeDataStoreTests {
    
    @Test("Data store initialization")
    func testDataStoreInitialization() async throws {
        let store = ThreadSafeDataStore<String>(capacity: 10)
        
        #expect(store.isEmpty == true)
        #expect(store.count == 0)
        #expect(store.capacity == 10)
    }
    
    @Test("Concurrent read and write operations")
    func testConcurrentOperations() async throws {
        let store = ThreadSafeDataStore<Int>(capacity: 1000)
        
        // Perform concurrent writes and reads
        await withTaskGroup(of: Void.self) { group in
            // Writer tasks
            for i in 0..<100 {
                group.addTask {
                    store.append(i)
                }
            }
            
            // Reader tasks
            for _ in 0..<50 {
                group.addTask {
                    _ = store.toArray()
                    _ = store.count
                    _ = store.isEmpty
                }
            }
            
            // Mixed operations
            for i in 100..<150 {
                group.addTask {
                    store.append(i)
                    _ = store.peek()
                }
            }
        }
        
        // Verify final state is consistent
        let finalCount = store.count
        let finalArray = store.toArray()
        
        #expect(finalArray.count == finalCount)
        #expect(finalCount <= 1000) // Within capacity
    }
    
    @Test("Data store filtering operations")
    func testFilteringOperations() async throws {
        let store = ThreadSafeDataStore<Int>(capacity: 20)
        
        // Add test data
        for i in 1...15 {
            store.append(i)
        }
        
        let evenNumbers = store.filter { $0 % 2 == 0 }
        let expectedEvens = [2, 4, 6, 8, 10, 12, 14]
        
        #expect(evenNumbers == expectedEvens)
        
        let largeNumbers = store.filter { $0 > 10 }
        #expect(largeNumbers == [11, 12, 13, 14, 15])
    }
    
    @Test("Data store batch operations")
    func testBatchOperations() async throws {
        let store = ThreadSafeDataStore<String>(capacity: 100)
        
        // Test batch read
        let elements = ["a", "b", "c", "d", "e"]
        for element in elements {
            store.append(element)
        }
        
        let result = store.performBatchRead { elements in
            return elements.joined(separator: "-")
        }
        
        #expect(result == "a-b-c-d-e")
    }
    
    @Test("Data store cleanup operations")
    func testCleanupOperations() async throws {
        let store = ThreadSafeDataStore<Int>(capacity: 50)
        
        // Add mixed data
        for i in 1...20 {
            store.append(i)
        }
        
        // Remove even numbers
        let removedCount = store.cleanup { $0 % 2 == 0 }
        
        #expect(removedCount >= 0)
        
        let remaining = store.toArray()
        let hasEvenNumbers = remaining.contains { $0 % 2 == 0 }
        #expect(hasEvenNumbers == false)
    }
    
    @Test("Data store snapshot functionality")
    func testSnapshotFunctionality() async throws {
        let store = ThreadSafeDataStore<String>(capacity: 30)
        
        let testData = ["apple", "banana", "cherry", "date"]
        for item in testData {
            store.append(item)
        }
        
        let snapshot = store.getSnapshot()
        
        #expect(snapshot.count == 4)
        #expect(snapshot.isEmpty == false)
        #expect(snapshot.elements == testData)
        
        // Snapshot should be immutable - changes to store don't affect it
        store.append("elderberry")
        #expect(snapshot.count == 4) // Unchanged
    }
    
    @Test("Data store capacity management")
    func testCapacityManagement() async throws {
        let store = ThreadSafeDataStore<Int>(capacity: 5)
        
        // Fill beyond capacity
        var droppedElements: [Int] = []
        for i in 1...8 {
            if let dropped = store.append(i) {
                droppedElements.append(dropped)
            }
        }
        
        #expect(droppedElements.count == 3) // Should have dropped 1, 2, 3
        #expect(droppedElements == [1, 2, 3])
        
        let remaining = store.toArray()
        #expect(remaining == [4, 5, 6, 7, 8])
    }
    
    @Test("Data store with custom types")
    func testCustomTypeOperations() async throws {
        struct LogEntry: Codable, Equatable {
            let level: String
            let message: String
            let timestamp: Date
        }
        
        let store = ThreadSafeDataStore<LogEntry>(capacity: 100)
        
        let entry1 = LogEntry(level: "INFO", message: "App started", timestamp: Date())
        let entry2 = LogEntry(level: "ERROR", message: "Network failed", timestamp: Date())
        let entry3 = LogEntry(level: "DEBUG", message: "User action", timestamp: Date())
        
        store.append(entry1)
        store.append(entry2)
        store.append(entry3)
        
        let errorEntries = store.filter { $0.level == "ERROR" }
        #expect(errorEntries.count == 1)
        #expect(errorEntries.first?.message == "Network failed")
        
        let messages = store.map { $0.message }
        #expect(messages == ["App started", "Network failed", "User action"])
    }
    
    @Test("Data store async operations")
    func testAsyncOperations() async throws {
        let store = ThreadSafeDataStore<String>(capacity: 20)
        
        // Test async append
        await withCheckedContinuation { continuation in
            store.asyncAppend("test") { droppedElement in
                #expect(droppedElement == nil)
                continuation.resume()
            }
        }
        
        // Test async array retrieval
        let elements = await withCheckedContinuation { continuation in
            store.asyncToArray { elements in
                continuation.resume(returning: elements)
            }
        }
        
        #expect(elements == ["test"])
        
        // Add more elements for filtering test
        store.append("apple")
        store.append("banana") 
        store.append("apricot")
        
        // Test async filtering
        let filteredResults = await withCheckedContinuation { continuation in
            store.asyncFilter({ $0.hasPrefix("a") }) { filtered in
                continuation.resume(returning: filtered)
            }
        }
        
        #expect(filteredResults == ["apple", "apricot"])
    }
    
    @Test("Data store performance characteristics")
    func testPerformanceCharacteristics() async throws {
        let store = ThreadSafeDataStore<Int>(capacity: 10000)
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform many operations
        for i in 0..<5000 {
            store.append(i)
        }
        
        let writeTime = CFAbsoluteTimeGetCurrent() - startTime
        
        let readStartTime = CFAbsoluteTimeGetCurrent()
        let _ = store.toArray()
        let readTime = CFAbsoluteTimeGetCurrent() - readStartTime
        
        // These are reasonable performance expectations
        #expect(writeTime < 1.0) // Should complete writes in under 1 second
        #expect(readTime < 0.1)  // Should complete read in under 100ms
        
        let stats = store.getStatistics()
        #expect(stats.currentCount == 5000)
        #expect(stats.utilizationPercentage == 50.0)
    }
}