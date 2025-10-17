//
//  ConditionalLogger.swift
//  BackgroundTime
//
//  Created on 10/16/25.
//

import Foundation
import os.log

/// A helper struct that provides conditional logging functionality based on the test environment
struct ConditionalLogger: Sendable {
    private let logger: Logger
    private let isTestEnvironment: Bool
    
    /// Initialize with a logger instance
    /// - Parameter logger: The Logger instance to use for actual logging
    init(logger: Logger) {
        self.logger = logger
        self.isTestEnvironment = Self.detectTestEnvironment()
    }
    
    /// Initialize with subsystem and category for convenience
    /// - Parameters:
    ///   - subsystem: The subsystem identifier for the logger
    ///   - category: The category for the logger
    init(subsystem: String, category: String) {
        self.init(logger: Logger(subsystem: subsystem, category: category))
    }
    
    /// Detect if running in a test environment
    private static func detectTestEnvironment() -> Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
               NSClassFromString("XCTestCase") != nil ||
               ProcessInfo.processInfo.arguments.contains("--test")
    }
    
    /// Log an info message, suppressed in test environments
    /// - Parameter message: The message to log
    func info(_ message: String) {
        guard !isTestEnvironment else { return }
        logger.info("\(message)")
    }
    
    /// Log a warning message, suppressed in test environments
    /// - Parameter message: The message to log
    func warning(_ message: String) {
        guard !isTestEnvironment else { return }
        logger.warning("\(message)")
    }
    
    /// Log an error message, suppressed in test environments
    /// - Parameter message: The message to log
    func error(_ message: String) {
        guard !isTestEnvironment else { return }
        logger.error("\(message)")
    }
    
    /// Log a debug message, suppressed in test environments
    /// - Parameter message: The message to log
    func debug(_ message: String) {
        guard !isTestEnvironment else { return }
        logger.debug("\(message)")
    }
    
    /// Log a notice message, suppressed in test environments
    /// - Parameter message: The message to log
    func notice(_ message: String) {
        guard !isTestEnvironment else { return }
        logger.notice("\(message)")
    }
    
    /// Log a critical message, suppressed in test environments
    /// - Parameter message: The message to log
    func critical(_ message: String) {
        guard !isTestEnvironment else { return }
        logger.critical("\(message)")
    }
    
    /// Log a fault message, suppressed in test environments
    /// - Parameter message: The message to log
    func fault(_ message: String) {
        guard !isTestEnvironment else { return }
        logger.fault("\(message)")
    }
    
    /// Get the current test environment detection status
    var testEnvironmentDetected: Bool {
        return isTestEnvironment
    }
    
    /// Get the underlying Logger instance (for advanced use cases)
    var underlyingLogger: Logger {
        return logger
    }
}