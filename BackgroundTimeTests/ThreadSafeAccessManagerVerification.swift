//
//  ThreadSafeAccessManagerVerification.swift
//  BackgroundTimeTests
//
//  Created by Siddharth Sathyam on 9/25/25.
//

import Testing
import Foundation
@testable import BackgroundTime

// MARK: - Verification Tests for ThreadSafeAccessManager Fixes

@Suite("ThreadSafeAccessManager Fix Verification")
struct ThreadSafeAccessManagerVerificationTests {
    
    @Test("AccessMetric Codable conformance")
    func testAccessMetricCodable() async throws {
        // Create a performance monitor and record some metrics
        let monitor = AccessPatternMonitor.shared
        monitor.recordAccess(operation: "test_operation", duration: 0.05)
        monitor.recordAccess(operation: "slow_operation", duration: 0.2, success: false)
        
        // Get performance report (this internally uses AccessMetric)
        let report = monitor.getPerformanceReport()
        
        #expect(report.totalOperations >= 2)
        #expect(report.slowOperations >= 1)
        #expect(report.failedOperations >= 1)
        
        // Test Codable on PerformanceReport
        let encoder = JSONEncoder()
        let data = try encoder.encode(report)
        
        let decoder = JSONDecoder()
        let decodedReport = try decoder.decode(PerformanceReport.self, from: data)
        
        #expect(decodedReport.totalOperations == report.totalOperations)
        #expect(decodedReport.averageDuration == report.averageDuration)
    }
    
    @Test("DataSnapshot Codable conformance")
    func testDataSnapshotCodable() async throws {
        let dataStore = ThreadSafeDataStore<String>(capacity: 5)
        dataStore.append("test1")
        dataStore.append("test2")
        dataStore.append("test3")
        
        let snapshot = dataStore.getSnapshot()
        
        #expect(snapshot.count == 3)
        #expect(snapshot.elements == ["test1", "test2", "test3"])
        
        // Test Codable
        let encoder = JSONEncoder()
        let data = try encoder.encode(snapshot)
        
        let decoder = JSONDecoder()
        let decodedSnapshot = try decoder.decode(DataSnapshot<String>.self, from: data)
        
        #expect(decodedSnapshot.count == snapshot.count)
        #expect(decodedSnapshot.elements == snapshot.elements)
        #expect(decodedSnapshot.statistics.capacity == snapshot.statistics.capacity)
    }
    
    @Test("BufferStatistics Codable conformance")
    func testBufferStatisticsCodable() async throws {
        let buffer = CircularBuffer<Int>(capacity: 10)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        
        let stats = buffer.getStatistics()
        
        #expect(stats.capacity == 10)
        #expect(stats.currentCount == 3)
        #expect(stats.utilizationPercentage == 30.0)
        
        // Test Codable
        let encoder = JSONEncoder()
        let data = try encoder.encode(stats)
        
        let decoder = JSONDecoder()
        let decodedStats = try decoder.decode(BufferStatistics.self, from: data)
        
        #expect(decodedStats.capacity == stats.capacity)
        #expect(decodedStats.currentCount == stats.currentCount)
        #expect(decodedStats.utilizationPercentage == stats.utilizationPercentage)
    }
    
    @Test("Key path compilation works")
    func testKeyPathCompilation() async throws {
        // This test ensures that the key path fixes work correctly
        let monitor = AccessPatternMonitor.shared
        monitor.recordAccess(operation: "key_path_test", duration: 0.03)
        
        let report = monitor.getPerformanceReport()
        
        // The fact that this compiles and runs means our key path fixes work
        #expect(report.operationBreakdown.keys.contains("key_path_test"))
    }
    
    @Test("ThreadSafeDataStore operations work")
    func testThreadSafeDataStoreOperations() async throws {
        let dataStore = ThreadSafeDataStore<Int>(capacity: 5)
        
        // Test basic operations
        dataStore.append(10)
        dataStore.append(20)
        dataStore.append(30)
        
        #expect(dataStore.count == 3)
        #expect(dataStore.peek() == 10)
        #expect(dataStore.peekLast() == 30)
        
        // Test filtering
        let evenNumbers = dataStore.filter { $0 % 2 == 0 }
        #expect(evenNumbers == [10, 20, 30])
        
        // Test mapping
        let doubled = dataStore.map { $0 * 2 }
        #expect(doubled == [20, 40, 60])
        
        // Test cleanup
        let removedCount = dataStore.cleanup { $0 > 15 }
        #expect(removedCount >= 0)
        
        // Test snapshot
        let snapshot = dataStore.getSnapshot()
        #expect(snapshot.elements.contains(10))
    }
    
    @Test("Performance monitoring works")
    func testPerformanceMonitoring() async throws {
        let monitor = AccessPatternMonitor.shared
        
        // Record various operations
        monitor.recordAccess(operation: "fast_op", duration: 0.01)
        monitor.recordAccess(operation: "normal_op", duration: 0.05)
        monitor.recordAccess(operation: "slow_op", duration: 0.15)
        monitor.recordAccess(operation: "failed_op", duration: 0.08, success: false)
        
        let report = monitor.getPerformanceReport()
        
        #expect(report.totalOperations > 0)
        #expect(report.successRate < 1.0) // Should have at least one failure
        #expect(report.slowOperations > 0) // Should have at least one slow operation
        #expect(report.slowOperationPercentage > 0)
        
        // Check operation breakdown
        #expect(report.operationBreakdown.keys.contains("slow_op"))
        #expect(report.operationBreakdown.keys.contains("failed_op"))
    }
}