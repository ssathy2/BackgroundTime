//
//  BackgroundTime.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Foundation
import BackgroundTasks
import UIKit
import os.log
import Combine

// MARK: - BackgroundTime SDK Main Class

@MainActor
public final class BackgroundTime: ObservableObject {
    public static let shared = BackgroundTime()
    
    private let logger = Logger(subsystem: "BackgroundTime", category: "SDK")
    public private(set) var isInitialized = false
    private let dataStore = BackgroundTaskDataStore.shared
    
    // Track swizzling status for debugging
    public private(set) var isSwizzlingEnabled = false
    
    private init() {
        logger.info("BackgroundTime SDK instance created")
    }
    
    /// Initialize BackgroundTime SDK with configuration
    public func initialize(configuration: BackgroundTimeConfiguration = .default) {
        guard !isInitialized else {
            logger.warning("BackgroundTime already initialized")
            return
        }
        
        // Configure data store with thread-safe circular buffer
        dataStore.configure(maxStoredEvents: configuration.maxStoredEvents)
        
        // Setup method swizzling on main actor
        setupMethodSwizzling()
        
        // Setup app lifecycle monitoring
        setupAppLifecycleMonitoring()
        
        isInitialized = true
        logger.info("BackgroundTime SDK initialized successfully")
        
        // Record initialization event
        recordSDKEvent(.metricKitDataReceived, metadata: [
            "version": "1.0.0", // BackgroundTimeConfiguration.sdkVersion
            "maxStoredEvents": configuration.maxStoredEvents,
            "detailedLogging": configuration.enableDetailedLogging
        ])
    }
    
    /// Get current background task statistics
    public func getCurrentStats() -> BackgroundTaskStatistics {
        return dataStore.generateStatistics()
    }
    
    /// Get all recorded events (for dashboard display)
    public func getAllEvents() -> [BackgroundTaskEvent] {
        return dataStore.getAllEvents()
    }
    
    /// Export data for dashboard display
    public func exportDataForDashboard() -> BackgroundTaskDashboardData {
        let stats = getCurrentStats()
        let events = getAllEvents()
        let timeline = generateTimelineData(from: events)
        let schedulingAnalyses = analyzeAllTaskScheduling()
        
        return BackgroundTaskDashboardData(
            statistics: stats,
            events: events,
            timeline: timeline,
            systemInfo: collectSystemInfo(),
            schedulingAnalyses: schedulingAnalyses
        )
    }
    
    /// Get data store performance metrics
    public func getDataStorePerformance() -> PerformanceReport {
        return dataStore.getDataStorePerformance()
    }
    
    /// Get buffer utilization statistics
    public func getBufferStatistics() -> BufferStatistics {
        return dataStore.getBufferStatistics()
    }
    
    // MARK: - Task Scheduling Analysis
    
    /// Analyze scheduling patterns for a specific task identifier
    /// This provides insights into how earliestBeginDate, network, and power requirements affect execution timing
    public func analyzeTaskScheduling(for taskIdentifier: String) -> TaskSchedulingAnalysis? {
        guard isInitialized else {
            logger.warning("BackgroundTime not initialized - cannot analyze task scheduling")
            return nil
        }
        
        let analyzer = TaskSchedulingAnalyzer()
        return analyzer.analyzeSchedulingPatterns(for: taskIdentifier)
    }
    
    /// Analyze scheduling patterns for all tasks
    /// Returns optimization insights for all tracked task identifiers
    public func analyzeAllTaskScheduling() -> [TaskSchedulingAnalysis] {
        guard isInitialized else {
            logger.warning("BackgroundTime not initialized - cannot analyze task scheduling")
            return []
        }
        
        let analyzer = TaskSchedulingAnalyzer()
        return analyzer.analyzeAllTasks()
    }
    
    /// Get scheduling optimization recommendations for a specific task
    public func getSchedulingRecommendations(for taskIdentifier: String) -> [SchedulingRecommendation] {
        guard let analysis = analyzeTaskScheduling(for: taskIdentifier) else {
            return []
        }
        return analysis.optimizationRecommendations
    }
    
    /// Record a test event (for testing purposes only)
    /// This method should only be used in test environments
    public func recordTestEvent(_ event: BackgroundTaskEvent) {
        guard isInitialized else {
            logger.warning("BackgroundTime not initialized - cannot record test event")
            return
        }
        dataStore.recordEvent(event)
    }
    
    // MARK: - Private Methods
    
    private func setupMethodSwizzling() {
        // Swizzle BGTaskScheduler methods
        BGTaskSchedulerSwizzler.swizzleSchedulerMethods()
        
        // Swizzle BGTask methods  
        BGTaskSwizzler.swizzleTaskMethods()

        
        // Mark swizzling as enabled
        isSwizzlingEnabled = true
        
        logger.info("🔧 Method swizzling enabled successfully")
    }
    
    private func setupAppLifecycleMonitoring() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.recordSDKEvent(.appEnteredBackground)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.recordSDKEvent(.appWillEnterForeground)
            }
        }
    }
    
    private func generateTimelineData(from events: [BackgroundTaskEvent]) -> [TimelineDataPoint] {
        return events.compactMap { event in
            // Filter out events with empty task identifiers from timeline
            // Also ensure we have a valid timestamp
            guard !event.taskIdentifier.isEmpty,
                  !event.taskIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
                return nil 
            }
            
            return TimelineDataPoint(
                timestamp: event.timestamp,
                eventType: event.type,
                taskIdentifier: event.taskIdentifier,
                duration: event.duration,
                success: event.success
            )
        }
    }
    
    private func collectSystemInfo() -> SystemInfo {
        return SystemInfo(
            backgroundAppRefreshStatus: UIApplication.shared.backgroundRefreshStatus,
            deviceModel: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            batteryLevel: UIDevice.current.batteryLevel,
            batteryState: UIDevice.current.batteryState
        )
    }
    
    private func recordSDKEvent(_ type: BackgroundTaskEventType, metadata: [String: any Sendable] = [:]) {
        // Convert metadata values to strings
        let stringMetadata = metadata.mapValues { value in
            String(describing: value)
        }
        
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "SDK_EVENT",
            type: type,
            timestamp: Date(),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: stringMetadata,
            systemInfo: collectSystemInfo()
        )
        dataStore.recordEvent(event)
    }
}





