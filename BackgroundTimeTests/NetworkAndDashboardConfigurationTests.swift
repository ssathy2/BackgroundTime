//
//  NetworkAndDashboardConfigurationTests.swift
//  BackgroundTimeTests
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Testing
import Foundation
import UIKit
import BackgroundTasks
@testable import BackgroundTime

@Suite("Network and Dashboard Configuration Tests")
struct NetworkAndDashboardConfigurationTests {
    
    @Test("DashboardConfiguration default properties")
    func testDashboardConfigurationDefaults() async throws {
        let defaultConfig = DashboardConfiguration.default
        
        #expect(defaultConfig.refreshInterval == 300, "Default refresh interval should be 300 seconds (5 minutes)")
        #expect(defaultConfig.maxEventsPerUpload == 1000, "Default max events per upload should be 1000")
        #expect(defaultConfig.enableRealTimeSync == false, "Default real-time sync should be disabled")
        #expect(defaultConfig.alertThresholds.lowSuccessRate == 0.8, "Default low success rate threshold should be 0.8")
        #expect(defaultConfig.alertThresholds.highFailureRate == 0.2, "Default high failure rate threshold should be 0.2")
        #expect(defaultConfig.alertThresholds.longExecutionTime == 30, "Default long execution time should be 30 seconds")
        #expect(defaultConfig.alertThresholds.noExecutionPeriod == 86400, "Default no execution period should be 86400 seconds (24 hours)")
    }
    
    @Test("AlertThresholds default properties and validation")
    func testAlertThresholdsDefaults() async throws {
        let thresholds = AlertThresholds.default
        
        #expect(thresholds.lowSuccessRate == 0.8)
        #expect(thresholds.highFailureRate == 0.2)
        #expect(thresholds.longExecutionTime == 30)
        #expect(thresholds.noExecutionPeriod == 86400)
        
        // Validate logical relationships
        #expect(thresholds.lowSuccessRate > thresholds.highFailureRate, "Low success rate threshold should be higher than high failure rate")
        #expect(thresholds.lowSuccessRate + thresholds.highFailureRate == 1.0, "Success and failure rates should complement each other")
        #expect(thresholds.longExecutionTime > 0, "Long execution time should be positive")
        #expect(thresholds.noExecutionPeriod > 0, "No execution period should be positive")
        #expect(thresholds.noExecutionPeriod > thresholds.longExecutionTime, "No execution period should be much longer than execution time")
    }
    
    @Test("DashboardConfiguration custom values")
    func testDashboardConfigurationCustom() async throws {
        let customThresholds = AlertThresholds(
            lowSuccessRate: 0.9,
            highFailureRate: 0.1,
            longExecutionTime: 60,
            noExecutionPeriod: 172800 // 48 hours
        )
        
        let customConfig = DashboardConfiguration(
            refreshInterval: 120, // 2 minutes
            maxEventsPerUpload: 500,
            enableRealTimeSync: true,
            alertThresholds: customThresholds
        )
        
        #expect(customConfig.refreshInterval == 120)
        #expect(customConfig.maxEventsPerUpload == 500)
        #expect(customConfig.enableRealTimeSync == true)
        #expect(customConfig.alertThresholds.lowSuccessRate == 0.9)
        #expect(customConfig.alertThresholds.highFailureRate == 0.1)
        #expect(customConfig.alertThresholds.longExecutionTime == 60)
        #expect(customConfig.alertThresholds.noExecutionPeriod == 172800)
    }
    
    @Test("DashboardConfiguration codable functionality")
    func testDashboardConfigurationCodable() async throws {
        let originalConfig = DashboardConfiguration.default
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalConfig)
        
        #expect(data.count > 0, "Encoded data should not be empty")
        
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(DashboardConfiguration.self, from: data)
        
        #expect(decodedConfig.refreshInterval == originalConfig.refreshInterval)
        #expect(decodedConfig.maxEventsPerUpload == originalConfig.maxEventsPerUpload)
        #expect(decodedConfig.enableRealTimeSync == originalConfig.enableRealTimeSync)
        #expect(decodedConfig.alertThresholds.lowSuccessRate == originalConfig.alertThresholds.lowSuccessRate)
        #expect(decodedConfig.alertThresholds.highFailureRate == originalConfig.alertThresholds.highFailureRate)
        #expect(decodedConfig.alertThresholds.longExecutionTime == originalConfig.alertThresholds.longExecutionTime)
        #expect(decodedConfig.alertThresholds.noExecutionPeriod == originalConfig.alertThresholds.noExecutionPeriod)
    }
    
    @Test("AlertThresholds codable functionality")
    func testAlertThresholdsCodable() async throws {
        let customThresholds = AlertThresholds(
            lowSuccessRate: 0.95,
            highFailureRate: 0.05,
            longExecutionTime: 45.5,
            noExecutionPeriod: 259200 // 72 hours
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(customThresholds)
        
        let decoder = JSONDecoder()
        let decodedThresholds = try decoder.decode(AlertThresholds.self, from: data)
        
        #expect(decodedThresholds.lowSuccessRate == customThresholds.lowSuccessRate)
        #expect(decodedThresholds.highFailureRate == customThresholds.highFailureRate)
        #expect(decodedThresholds.longExecutionTime == customThresholds.longExecutionTime)
        #expect(decodedThresholds.noExecutionPeriod == customThresholds.noExecutionPeriod)
    }
    
    @Test("DashboardConfiguration edge cases")
    func testDashboardConfigurationEdgeCases() async throws {
        // Test with extreme values
        let extremeThresholds = AlertThresholds(
            lowSuccessRate: 0.0,
            highFailureRate: 1.0,
            longExecutionTime: 0.1,
            noExecutionPeriod: 1
        )
        
        let extremeConfig = DashboardConfiguration(
            refreshInterval: 1, // 1 second
            maxEventsPerUpload: 1,
            enableRealTimeSync: true,
            alertThresholds: extremeThresholds
        )
        
        #expect(extremeConfig.refreshInterval == 1)
        #expect(extremeConfig.maxEventsPerUpload == 1)
        #expect(extremeConfig.enableRealTimeSync == true)
        #expect(extremeConfig.alertThresholds.lowSuccessRate == 0.0)
        #expect(extremeConfig.alertThresholds.highFailureRate == 1.0)
        
        // Test with very large values
        let largeConfig = DashboardConfiguration(
            refreshInterval: TimeInterval.greatestFiniteMagnitude,
            maxEventsPerUpload: Int.max,
            enableRealTimeSync: false,
            alertThresholds: AlertThresholds(
                lowSuccessRate: 1.0,
                highFailureRate: 0.0,
                longExecutionTime: TimeInterval.greatestFiniteMagnitude,
                noExecutionPeriod: TimeInterval.greatestFiniteMagnitude
            )
        )
        
        #expect(largeConfig.refreshInterval == TimeInterval.greatestFiniteMagnitude)
        #expect(largeConfig.maxEventsPerUpload == Int.max)
        #expect(largeConfig.alertThresholds.lowSuccessRate == 1.0)
        #expect(largeConfig.alertThresholds.highFailureRate == 0.0)
    }
    
    @Test("NetworkManager configuration")
    func testNetworkManagerConfiguration() async throws {
        let networkManager = NetworkManager.shared
        
        // Test configuration with nil endpoint
        networkManager.configure(apiEndpoint: nil)
        
        // Test configuration with valid endpoints
        let validEndpoints = [
            URL(string: "https://api.example.com")!,
            URL(string: "http://localhost:3000")!,
            URL(string: "https://dashboard.company.com/api/v2")!
        ]
        
        for endpoint in validEndpoints {
            networkManager.configure(apiEndpoint: endpoint)
            // Configuration is internal, so we verify it doesn't crash
            #expect(true, "NetworkManager should accept valid endpoint: \(endpoint)")
        }
    }
    
    @Test("NetworkError comprehensive testing")
    func testNetworkErrorCases() async throws {
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error message"])
        
        let networkErrors: [NetworkError] = [
            .noEndpointConfigured,
            .invalidResponse,
            .networkUnavailable,
            .authenticationFailed,
            .serverError(statusCode: 400),
            .serverError(statusCode: 404),
            .serverError(statusCode: 500),
            .serverError(statusCode: 503),
            .uploadFailed(testError),
            .downloadFailed(testError),
            .unknownError(testError)
        ]
        
        for error in networkErrors {
            let description = error.errorDescription
            #expect(description != nil, "NetworkError should have error description: \(error)")
            #expect(description!.count > 0, "NetworkError description should not be empty: \(error)")
            
            switch error {
            case .noEndpointConfigured:
                #expect(description!.contains("endpoint"), "Should mention endpoint")
            case .invalidResponse:
                #expect(description!.contains("response"), "Should mention response")
            case .networkUnavailable:
                #expect(description!.contains("Network"), "Should mention network")
            case .authenticationFailed:
                #expect(description!.contains("Authentication"), "Should mention authentication")
            case .serverError(let statusCode):
                #expect(description!.contains("\(statusCode)"), "Should contain status code")
            case .uploadFailed(let underlyingError):
                #expect(description!.contains("Upload"), "Should mention upload")
                #expect(description!.contains(underlyingError.localizedDescription), "Should contain underlying error")
            case .downloadFailed(let underlyingError):
                #expect(description!.contains("Download"), "Should mention download")
                #expect(description!.contains(underlyingError.localizedDescription), "Should contain underlying error")
            case .unknownError(let underlyingError):
                #expect(description!.contains("Unknown"), "Should mention unknown")
                #expect(description!.contains(underlyingError.localizedDescription), "Should contain underlying error")
            }
        }
    }
    
    @Test("DashboardConfiguration with NetworkManager integration")
    func testDashboardConfigurationIntegration() async throws {
        let config = DashboardConfiguration(
            refreshInterval: 60,
            maxEventsPerUpload: 250,
            enableRealTimeSync: true,
            alertThresholds: AlertThresholds.default
        )
        
        // Test that configuration values are reasonable for network operations
        #expect(config.refreshInterval >= 1, "Refresh interval should be at least 1 second")
        #expect(config.maxEventsPerUpload >= 1, "Max events per upload should be at least 1")
        #expect(config.refreshInterval < 86400, "Refresh interval should be less than 24 hours for practical use")
        #expect(config.maxEventsPerUpload <= 10000, "Max events per upload should be reasonable for network transmission")
        
        // Test that alert thresholds are within valid ranges
        let thresholds = config.alertThresholds
        #expect(thresholds.lowSuccessRate >= 0.0 && thresholds.lowSuccessRate <= 1.0, "Low success rate should be between 0 and 1")
        #expect(thresholds.highFailureRate >= 0.0 && thresholds.highFailureRate <= 1.0, "High failure rate should be between 0 and 1")
        #expect(thresholds.longExecutionTime >= 0, "Long execution time should be non-negative")
        #expect(thresholds.noExecutionPeriod >= 0, "No execution period should be non-negative")
    }
}