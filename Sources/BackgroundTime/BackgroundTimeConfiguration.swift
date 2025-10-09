//
//  BackgroundTimeConfiguration.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Foundation

// MARK: - BackgroundTime Configuration

public struct BackgroundTimeConfiguration: Sendable {
    public static let sdkVersion = "1.0.0"
    
    public let maxStoredEvents: Int
    public let enableDetailedLogging: Bool
    
    public static let `default` = BackgroundTimeConfiguration(
        maxStoredEvents: 1000,
        enableDetailedLogging: true
    )
    
    public init(
        maxStoredEvents: Int = 1000,
        enableDetailedLogging: Bool = true
    ) {
        self.maxStoredEvents = maxStoredEvents
        self.enableDetailedLogging = enableDetailedLogging
    }
    
    var description: String {
        return "maxEvents: \(maxStoredEvents), detailedLogging: \(enableDetailedLogging)"
    }
}
