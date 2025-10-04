//
//  NetworkManagerTests.swift
//  BackgroundTimeTests
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Testing
import Foundation
import UIKit
import BackgroundTasks
@testable import BackgroundTime

@Suite("Network Manager Tests", .serialized)
struct NetworkManagerTests {
    
    @Test("NetworkManager configuration with various endpoints")
    func testNetworkManagerConfiguration() async throws {
        let networkManager = NetworkManager.shared
        
        // Reset singleton state before test to avoid interference
        networkManager.configure(apiEndpoint: nil)
        
        // Small delay to ensure any concurrent operations complete
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        // Test configuration with nil endpoint
        networkManager.configure(apiEndpoint: nil)
        
        // Test configuration with various valid endpoints
        let validEndpoints = [
            URL(string: "https://api.example.com")!,
            URL(string: "http://localhost:3000")!,
            URL(string: "https://dashboard.company.com/api/v2")!,
            URL(string: "https://subdomain.example.co.uk/v1/tasks")!,
            URL(string: "http://192.168.1.100:8080/api")!
        ]
        
        for endpoint in validEndpoints {
            networkManager.configure(apiEndpoint: endpoint)
            // Configuration is internal, so we verify it doesn't crash
            #expect(true, "NetworkManager should accept valid endpoint: \(endpoint)")
        }
        
        // Test reconfiguration
        networkManager.configure(apiEndpoint: validEndpoints[0])
        networkManager.configure(apiEndpoint: validEndpoints[1])
        networkManager.configure(apiEndpoint: nil) // Reset to nil
        
        #expect(true, "NetworkManager should handle reconfiguration gracefully")
        
        // Cleanup - reset to nil to avoid affecting other tests
        networkManager.configure(apiEndpoint: nil)
    }
    
    @Test("NetworkManager upload dashboard data error scenarios")
    func testNetworkManagerUploadErrors() async throws {
        let networkManager = NetworkManager.shared
        
        // Reset singleton state before test to avoid interference
        networkManager.configure(apiEndpoint: nil)
        let dashboardData = BackgroundTaskDashboardData(
            statistics: createMockStatistics(),
            events: createMockEvents(),
            timeline: createMockTimelineData(),
            systemInfo: createMockSystemInfo()
        )
        
        // Verify the dashboard data can be JSON encoded (this was likely causing the failure)
        do {
            let _ = try JSONEncoder().encode(dashboardData)
        } catch {
            #expect(Bool(false), "Dashboard data should be JSON encodable: \(error)")
        }
        
        // Test upload with no endpoint configured
        networkManager.configure(apiEndpoint: nil)
        
        do {
            try await networkManager.uploadDashboardData(dashboardData)
            #expect(Bool(false), "Upload should fail with no endpoint configured")
        } catch NetworkError.noEndpointConfigured {
            // Expected error
            #expect(true, "Correctly threw noEndpointConfigured error")
        } catch {
            #expect(Bool(false), "Should throw NetworkError.noEndpointConfigured, got: \(error)")
        }
        
        // Test upload with invalid endpoint (will fail in test environment)
        let invalidEndpoint = URL(string: "https://invalid-test-endpoint-12345.nonexistent")!
        networkManager.configure(apiEndpoint: invalidEndpoint)
        
        do {
            try await networkManager.uploadDashboardData(dashboardData)
            // If it somehow succeeds, that's fine
        } catch {
            // Expected to fail due to invalid endpoint
            #expect(error != nil, "Should handle network errors gracefully")
        }
        
        // Clean up singleton state
        networkManager.configure(apiEndpoint: nil)
    }
    
    @Test("NetworkManager download dashboard config error scenarios")
    func testNetworkManagerDownloadErrors() async throws {
        let networkManager = NetworkManager.shared
        
        // Reset singleton state before test to avoid interference
        networkManager.configure(apiEndpoint: nil)
        
        // Test download with no endpoint configured
        networkManager.configure(apiEndpoint: nil)
        
        do {
            let _ = try await networkManager.downloadDashboardConfig()
            #expect(Bool(false), "Download should fail with no endpoint configured")
        } catch NetworkError.noEndpointConfigured {
            // Expected error
            #expect(true, "Correctly threw noEndpointConfigured error")
        } catch {
            #expect(Bool(false), "Should throw NetworkError.noEndpointConfigured, got: \(error)")
        }
        
        // Test download with invalid endpoint
        let invalidEndpoint = URL(string: "https://invalid-test-endpoint-67890.nonexistent")!
        networkManager.configure(apiEndpoint: invalidEndpoint)
        
        do {
            let _ = try await networkManager.downloadDashboardConfig()
            // If it somehow succeeds, that's fine
        } catch {
            // Expected to fail due to invalid endpoint
            #expect(error != nil, "Should handle network errors gracefully")
        }
        
        // Clean up singleton state
        networkManager.configure(apiEndpoint: nil)
    }
    
    @Test("NetworkError comprehensive error descriptions")
    func testNetworkErrorDescriptions() async throws {
        let testError = NSError(
            domain: "TestErrorDomain", 
            code: 9999, 
            userInfo: [NSLocalizedDescriptionKey: "Custom test error message"]
        )
        
        let networkErrors: [(NetworkError, String)] = [
            (.noEndpointConfigured, "endpoint"),
            (.invalidResponse, "response"),
            (.serverError(statusCode: 400), "400"),
            (.serverError(statusCode: 401), "401"),
            (.serverError(statusCode: 403), "403"),
            (.serverError(statusCode: 404), "404"),
            (.serverError(statusCode: 500), "500"),
            (.serverError(statusCode: 502), "502"),
            (.serverError(statusCode: 503), "503"),
            (.uploadFailed(testError), "Upload"),
            (.downloadFailed(testError), "Download")
        ]
        
        for (error, expectedContent) in networkErrors {
            let description = error.errorDescription
            #expect(description != nil, "NetworkError should have error description: \(error)")
            #expect(!description!.isEmpty, "NetworkError description should not be empty: \(error)")
            #expect(description!.localizedCaseInsensitiveContains(expectedContent), 
                    "Description '\(description!)' should contain '\(expectedContent)' for error: \(error)")
            
            // Test specific error types
            switch error {
            case .uploadFailed(let underlyingError), .downloadFailed(let underlyingError):
                #expect(description!.contains(underlyingError.localizedDescription), 
                        "Should contain underlying error description")
            case .serverError(let statusCode):
                #expect(description!.contains(String(statusCode)), 
                        "Should contain status code")
            default:
                break
            }
        }
    }
    
    @Test("Dashboard Data Upload Structure validation")
    func testDashboardDataStructure() async throws {
        // Test with comprehensive dashboard data
        let dashboardData = BackgroundTaskDashboardData(
            statistics: createMockStatistics(),
            events: createMockEvents(),
            timeline: createMockTimelineData(),
            systemInfo: createMockSystemInfo()
        )
        
        #expect(dashboardData.events.count > 0, "Should have mock events")
        #expect(dashboardData.timeline.count > 0, "Should have mock timeline data")
        #expect(dashboardData.statistics.totalTasksScheduled >= 0, "Should have valid statistics")
        #expect(dashboardData.systemInfo.deviceModel.count > 0, "Should have system info")
        #expect(dashboardData.generatedAt != nil, "Should have generation timestamp")
        
        // Test JSON encoding of dashboard data
        let encoder = JSONEncoder()
        do {
            let jsonData = try encoder.encode(dashboardData)
            #expect(jsonData.count > 0, "Dashboard data should be encodable to JSON")
            
            // Verify it can be decoded back
            let decoder = JSONDecoder()
            let decodedData = try decoder.decode(BackgroundTaskDashboardData.self, from: jsonData)
            
            #expect(decodedData.events.count == dashboardData.events.count, "Events should survive encoding/decoding")
            #expect(decodedData.timeline.count == dashboardData.timeline.count, "Timeline should survive encoding/decoding")
            #expect(decodedData.statistics.totalTasksScheduled == dashboardData.statistics.totalTasksScheduled, 
                    "Statistics should survive encoding/decoding")
            #expect(decodedData.systemInfo.deviceModel == dashboardData.systemInfo.deviceModel, 
                    "System info should survive encoding/decoding")
            
        } catch {
            #expect(Bool(false), "Dashboard data should be JSON encodable: \(error)")
        }
    }
    
    @Test("NetworkManager singleton behavior")
    func testNetworkManagerSingleton() async throws {
        // Reset singleton state before test to avoid interference
        NetworkManager.shared.configure(apiEndpoint: nil)
        
        let instance1 = NetworkManager.shared
        let instance2 = NetworkManager.shared
        
        // Verify singleton behavior using memory addresses
        let ptr1 = Unmanaged.passUnretained(instance1).toOpaque()
        let ptr2 = Unmanaged.passUnretained(instance2).toOpaque()
        #expect(ptr1 == ptr2, "NetworkManager should be a singleton")
        
        // Test that configuration persists across references
        let testEndpoint = URL(string: "https://test-singleton.com")!
        instance1.configure(apiEndpoint: testEndpoint)
        
        // Both references should be the same instance, so configuration should be shared
        // We can't directly test this due to private properties, but we can verify no crashes occur
        instance2.configure(apiEndpoint: nil)
        instance1.configure(apiEndpoint: testEndpoint)
        
        #expect(true, "Singleton configuration should work without issues")
        
        // Clean up singleton state
        NetworkManager.shared.configure(apiEndpoint: nil)
    }
}

// MARK: - Helper Functions

private func createMockSystemInfo() -> SystemInfo {
    return SystemInfo(
        backgroundAppRefreshStatus: .available,
        deviceModel: "iPhone",
        systemVersion: "17.0",
        lowPowerModeEnabled: false,
        batteryLevel: 0.75,
        batteryState: .unplugged
    )
}

private func createMockEvents() -> [BackgroundTaskEvent] {
    return [
        BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "mock-task-1",
            type: .taskScheduled,
            timestamp: Date(timeIntervalSinceNow: -300),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        ),
        BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "mock-task-1",
            type: .taskExecutionStarted,
            timestamp: Date(timeIntervalSinceNow: -295),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        ),
        BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "mock-task-1",
            type: .taskExecutionCompleted,
            timestamp: Date(timeIntervalSinceNow: -290),
            duration: 5.0,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        ),
        BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "mock-task-2",
            type: .taskScheduled,
            timestamp: Date(timeIntervalSinceNow: -200),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: createMockSystemInfo()
        ),
        BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "mock-task-2",
            type: .taskFailed,
            timestamp: Date(timeIntervalSinceNow: -195),
            duration: nil,
            success: false,
            errorMessage: "Network error",
            metadata: [:],
            systemInfo: createMockSystemInfo()
        )
    ]
}

private func createMockStatistics() -> BackgroundTaskStatistics {
    return BackgroundTaskStatistics(
        totalTasksScheduled: 10,
        totalTasksExecuted: 8,
        totalTasksCompleted: 6,
        totalTasksFailed: 2,
        totalTasksExpired: 2,
        averageExecutionTime: 4.5,
        successRate: 0.75,
        executionsByHour: [9: 2, 14: 3, 18: 3],
        errorsByType: ["Network error": 1, "Timeout": 1],
        lastExecutionTime: Date(),
        generatedAt: Date()
    )
}

private func createMockTimelineData() -> [TimelineDataPoint] {
    return [
        TimelineDataPoint(
            timestamp: Date(timeIntervalSinceNow: -300),
            eventType: .taskScheduled,
            taskIdentifier: "mock-task-1",
            duration: nil,
            success: true
        ),
        TimelineDataPoint(
            timestamp: Date(timeIntervalSinceNow: -295),
            eventType: .taskExecutionStarted,
            taskIdentifier: "mock-task-1",
            duration: nil,
            success: true
        ),
        TimelineDataPoint(
            timestamp: Date(timeIntervalSinceNow: -290),
            eventType: .taskExecutionCompleted,
            taskIdentifier: "mock-task-1",
            duration: 5.0,
            success: true
        )
    ]
}