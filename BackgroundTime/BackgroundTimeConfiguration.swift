//
//  BackgroundTimeConfiguration.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Foundation

// MARK: - BackgroundTime Configuration

public struct BackgroundTimeConfiguration {
    public static let sdkVersion = "1.0.0"
    
    public let maxStoredEvents: Int
    public let apiEndpoint: URL?
    public let enableNetworkSync: Bool
    public let enableDetailedLogging: Bool
    
    public static let `default` = BackgroundTimeConfiguration(
        maxStoredEvents: 1000,
        apiEndpoint: nil,
        enableNetworkSync: false,
        enableDetailedLogging: true
    )
    
    public init(
        maxStoredEvents: Int = 1000,
        apiEndpoint: URL? = nil,
        enableNetworkSync: Bool = false,
        enableDetailedLogging: Bool = true
    ) {
        self.maxStoredEvents = maxStoredEvents
        self.apiEndpoint = apiEndpoint
        self.enableNetworkSync = enableNetworkSync
        self.enableDetailedLogging = enableDetailedLogging
    }
    
    var description: String {
        return "maxEvents: \(maxStoredEvents), networkSync: \(enableNetworkSync)"
    }
}
