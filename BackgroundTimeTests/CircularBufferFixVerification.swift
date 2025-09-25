//
//  CircularBufferFixVerification.swift
//  BackgroundTimeTests
//
//  Created by Siddharth Sathyam on 9/25/25.
//

import Testing
import Foundation
@testable import BackgroundTime

// MARK: - Verification Tests for CircularBuffer Fixes

@Suite("CircularBuffer Fix Verification")
struct CircularBufferFixVerificationTests {
    
    @Test("Buffer initialization works correctly")
    func testBufferInitialization() async throws {
        let buffer = CircularBuffer<String>(capacity: 5)
        
        #expect(buffer.isEmpty == true)
        #expect(buffer.capacity == 5)
        #expect(buffer.currentCount == 0)
    }
    
    @Test("Buffer append and retrieval works")
    func testBasicOperations() async throws {
        let buffer = CircularBuffer<Int>(capacity: 3)
        
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        
        #expect(buffer.isFull == true)
        #expect(buffer.peek() == 1)
        #expect(buffer.peekLast() == 3)
        
        let array = buffer.toArray()
        #expect(array == [1, 2, 3])
    }
    
    @Test("Buffer overflow handling")
    func testOverflowHandling() async throws {
        let buffer = CircularBuffer<String>(capacity: 2)
        
        let dropped1 = buffer.append("first")
        let dropped2 = buffer.append("second")
        let dropped3 = buffer.append("third") // Should drop "first"
        
        #expect(dropped1 == nil)
        #expect(dropped2 == nil)
        #expect(dropped3 == "first")
        
        let contents = buffer.toArray()
        #expect(contents == ["second", "third"])
    }
    
    @Test("Buffer resize creates new buffer")
    func testResizeReturnsNewBuffer() async throws {
        let originalBuffer = CircularBuffer<Int>(capacity: 5)
        
        originalBuffer.append(10)
        originalBuffer.append(20)
        originalBuffer.append(30)
        
        let _originalBuffer = originalBuffer
        originalBuffer.resize(to: 2)
        
        // Original buffer should be unchanged
        #expect(_originalBuffer.capacity == 5)
        #expect(_originalBuffer.toArray() == [10, 20, 30])
        
        // New buffer should have different capacity and keep most recent elements
        #expect(originalBuffer.capacity == 2)
        #expect(originalBuffer.toArray() == [20, 30])
    }
    
    @Test("Buffer clear operation")
    func testClearOperation() async throws {
        let buffer = CircularBuffer<String>(capacity: 10)
        
        buffer.append("a")
        buffer.append("b")
        buffer.append("c")
        
        #expect(buffer.currentCount == 3)
        
        buffer.clear()
        
        #expect(buffer.isEmpty == true)
        #expect(buffer.currentCount == 0)
        #expect(buffer.toArray().isEmpty == true)
    }
    
    @Test("Codable support works")
    func testCodableSupport() async throws {
        let originalBuffer = CircularBuffer<String>(capacity: 3)
        originalBuffer.append("hello")
        originalBuffer.append("world")
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalBuffer)
        
        // Decode
        let decoder = JSONDecoder()
        let decodedBuffer = try decoder.decode(CircularBuffer<String>.self, from: data)
        
        #expect(decodedBuffer.capacity == 3)
        #expect(decodedBuffer.toArray() == ["hello", "world"])
    }
    
    @Test("ThreadSafeDataStore integration")
    func testThreadSafeDataStoreIntegration() async throws {
        let dataStore = ThreadSafeDataStore<Int>(capacity: 5)
        
        dataStore.append(100)
        dataStore.append(200)
        dataStore.append(300)
        
        #expect(dataStore.count == 3)
        #expect(dataStore.toArray() == [100, 200, 300])
        
        // Test resize (should work with ThreadSafeDataStore)
        dataStore.resize(to: 2)
        
        let afterResize = dataStore.toArray()
        #expect(afterResize == [200, 300])
        #expect(dataStore.capacity == 2)
    }
}
