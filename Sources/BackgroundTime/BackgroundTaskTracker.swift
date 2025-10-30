//
//  BackgroundTaskTracker.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/25/25.
//

import Foundation
import BackgroundTasks
import os.log

// MARK: - Public API for Background Task Tracking

@MainActor
public class BackgroundTaskTracker {
    public static let shared = BackgroundTaskTracker()
    
    private let logger = Logger(subsystem: "BackgroundTime", category: "TaskTracker")
    private let metricCollector = MetricCollectionManager.shared
    private var activeTaskExecutions: Set<String> = []
    
    private init() {}
    
    // MARK: - Task Execution Tracking
    
    /// Call this at the beginning of your background task execution
    public func startExecution(for taskIdentifier: String) {
        guard !activeTaskExecutions.contains(taskIdentifier) else {
            logger.warning("Task execution already started for: \(taskIdentifier)")
            return
        }
        
        activeTaskExecutions.insert(taskIdentifier)
        metricCollector.recordTaskExecutionStart(identifier: taskIdentifier)
        
        logger.info("Started execution tracking for task: \(taskIdentifier)")
    }
    
    /// Call this when your background task completes successfully
    public func completeExecution(for taskIdentifier: String) {
        guard activeTaskExecutions.contains(taskIdentifier) else {
            logger.warning("No active execution found for task: \(taskIdentifier)")
            return
        }
        
        activeTaskExecutions.remove(taskIdentifier)
        metricCollector.recordTaskExecutionEnd(identifier: taskIdentifier, success: true)
        
        logger.info("Completed execution tracking for task: \(taskIdentifier)")
    }
    
    /// Call this when your background task fails
    public func failExecution(for taskIdentifier: String, error: Error? = nil) {
        guard activeTaskExecutions.contains(taskIdentifier) else {
            logger.warning("No active execution found for task: \(taskIdentifier)")
            return
        }
        
        activeTaskExecutions.remove(taskIdentifier)
        metricCollector.recordTaskExecutionEnd(identifier: taskIdentifier, success: false, error: error)
        
        logger.info("Failed execution tracking for task: \(taskIdentifier) - Error: \(error?.localizedDescription ?? "Unknown")")
    }
    
    /// Call this when your background task expires
    public func expireExecution(for taskIdentifier: String) {
        guard activeTaskExecutions.contains(taskIdentifier) else {
            logger.warning("No active execution found for task: \(taskIdentifier)")
            return
        }
        
        activeTaskExecutions.remove(taskIdentifier)
        metricCollector.recordTaskExpiration(identifier: taskIdentifier)
        
        logger.info("Expired execution tracking for task: \(taskIdentifier)")
    }
    
    // MARK: - Convenience Methods
    
    /// Wrapper for executing background tasks with automatic tracking
    public func executeTask<T>(
        identifier: String,
        task: @Sendable () async throws -> T
    ) async -> Result<T, Error> {
        startExecution(for: identifier)
        
        do {
            let result = try await task()
            completeExecution(for: identifier)
            return .success(result)
        } catch {
            failExecution(for: identifier, error: error)
            return .failure(error)
        }
    }
    
    /// Wrapper for BGTask execution with proper lifecycle management
    public func executeBGTask(
        _ bgTask: BGTask,
        handler: @Sendable @escaping () async throws -> Void
    ) {
        let taskIdentifier = bgTask.identifier
        
        // Set expiration handler
        bgTask.expirationHandler = { [weak self] in
            Task { @MainActor in
                self?.expireExecution(for: taskIdentifier)
                bgTask.setTaskCompleted(success: false)
            }
        }
        
        startExecution(for: taskIdentifier)
        
        Task {
            do {
                try await handler()
                await MainActor.run {
                    completeExecution(for: taskIdentifier)
                    bgTask.setTaskCompleted(success: true)
                }
            } catch {
                await MainActor.run {
                    failExecution(for: taskIdentifier, error: error)
                    bgTask.setTaskCompleted(success: false)
                }
            }
        }
    }
    
    // MARK: - Active Task Management
    
    public var activeTaskCount: Int {
        activeTaskExecutions.count
    }
    
    public var activeTaskIdentifiers: [String] {
        Array(activeTaskExecutions)
    }
    
    public func isExecuting(_ taskIdentifier: String) -> Bool {
        activeTaskExecutions.contains(taskIdentifier)
    }
    
    /// Force cleanup of stale task executions (use carefully)
    public func cleanupStaleExecutions() {
        let staleExecutions = activeTaskExecutions
        activeTaskExecutions.removeAll()
        
        for identifier in staleExecutions {
            metricCollector.recordTaskExecutionEnd(
                identifier: identifier,
                success: false,
                error: BackgroundTaskError.taskCancelled
            )
        }
        
        logger.warning("Cleaned up \(staleExecutions.count) stale task executions")
    }
    
    // MARK: - Network Request Tracking
    
    /// Track network requests made during background task execution
    public func recordNetworkRequest(
        for taskIdentifier: String,
        bytesTransferred: Int64,
        success: Bool,
        latency: TimeInterval? = nil
    ) {
        logger.debug("Recording network request for task: \(taskIdentifier), bytes: \(bytesTransferred), success: \(success)")
        
        // This could be expanded to integrate with the NetworkMetricsCollector
        // For now, we'll add it to the task's metadata when it completes
    }
    
    // MARK: - Custom Metrics
    
    /// Add custom metadata to the currently executing task
    public func addMetadata(
        for taskIdentifier: String,
        key: String,
        value: Any
    ) {
        guard activeTaskExecutions.contains(taskIdentifier) else {
            logger.warning("Cannot add metadata for inactive task: \(taskIdentifier)")
            return
        }
        
        logger.debug("Adding metadata for task: \(taskIdentifier), key: \(key)")
        // Custom metadata would be stored and included when the task completes
    }
}
