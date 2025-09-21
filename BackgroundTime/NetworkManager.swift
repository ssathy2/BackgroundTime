//
//  NetworkManager.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Foundation
import os.log

// MARK: - Network Manager for Dashboard Sync

class NetworkManager {
    static let shared = NetworkManager()
        
    private let logger = Logger(subsystem: "BackgroundTime", category: "Network")
    private var apiEndpoint: URL?
    private let session = URLSession(configuration: .default)
    
    private init() {}
    
    func configure(apiEndpoint: URL?) {
        self.apiEndpoint = apiEndpoint
    }
    
    func uploadDashboardData(_ data: BackgroundTaskDashboardData) async throws {
        guard let endpoint = apiEndpoint else {
            throw NetworkError.noEndpointConfigured
        }
        
        var request = URLRequest(url: endpoint.appendingPathComponent("/api/background-tasks/upload"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(data)
            request.httpBody = jsonData
            
            let (responseData, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw NetworkError.serverError(statusCode: httpResponse.statusCode)
            }
            
            logger.info("Successfully uploaded dashboard data")
            
        } catch let error as NetworkError {
            throw error
        } catch {
            logger.error("Failed to upload dashboard data: \(error.localizedDescription)")
            throw NetworkError.uploadFailed(error)
        }
    }
    
    func downloadDashboardConfig() async throws -> DashboardConfiguration {
        guard let endpoint = apiEndpoint else {
            throw NetworkError.noEndpointConfigured
        }
        
        let configURL = endpoint.appendingPathComponent("/api/dashboard/config")
        
        do {
            let (data, response) = try await session.data(from: configURL)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NetworkError.invalidResponse
            }
            
            let config = try JSONDecoder().decode(DashboardConfiguration.self, from: data)
            return config
            
        } catch {
            logger.error("Failed to download dashboard config: \(error.localizedDescription)")
            throw NetworkError.downloadFailed(error)
        }
    }
}

// MARK: - Network Error Types

enum NetworkError: Error, LocalizedError {
    case noEndpointConfigured
    case invalidResponse
    case serverError(statusCode: Int)
    case uploadFailed(Error)
    case downloadFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noEndpointConfigured:
            return "No API endpoint configured for dashboard sync"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let statusCode):
            return "Server error with status code: \(statusCode)"
        case .uploadFailed(let error):
            return "Upload failed: \(error.localizedDescription)"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Dashboard Configuration

public struct DashboardConfiguration: Codable {
    public let refreshInterval: TimeInterval
    public let maxEventsPerUpload: Int
    public let enableRealTimeSync: Bool
    public let alertThresholds: AlertThresholds
    
    public static let `default` = DashboardConfiguration(
        refreshInterval: 300, // 5 minutes
        maxEventsPerUpload: 1000,
        enableRealTimeSync: false,
        alertThresholds: AlertThresholds.default
    )
}

public struct AlertThresholds: Codable {
    public let lowSuccessRate: Double
    public let highFailureRate: Double
    public let longExecutionTime: TimeInterval
    public let noExecutionPeriod: TimeInterval
    
    public static let `default` = AlertThresholds(
        lowSuccessRate: 0.8, // Alert if success rate drops below 80%
        highFailureRate: 0.2, // Alert if failure rate exceeds 20%
        longExecutionTime: 30, // Alert if execution time exceeds 30 seconds
        noExecutionPeriod: 86400 // Alert if no executions for 24 hours
    )
}
