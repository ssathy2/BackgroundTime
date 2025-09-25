//
//  MetricCollectionManager.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/25/25.
//

import Foundation
import MetricKit
import os.log
import UIKit
import BackgroundTasks
import Darwin

// MARK: - Enhanced Metric Collection Manager

@MainActor
@objc class MetricCollectionManager: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricCollectionManager()
    
    private let logger = Logger(subsystem: "BackgroundTime", category: "MetricCollection")
    private let dataStore = BackgroundTaskDataStore.shared
    private let performanceMonitor = PerformanceMetricsCollector()
    private let systemResourceMonitor = SystemResourceMonitor()
    private let networkMonitor = NetworkMetricsCollector()
    
    // MetricKit integration
    private var metricManager: MXMetricManager!
    private var isMetricKitEnabled = false
    
    // Internal tracking
    private var taskExecutionStartTimes: [String: CFAbsoluteTime] = [:]
    private var taskSchedulingTimes: [String: CFAbsoluteTime] = [:]
    
    // Helper function to create SystemInfo
    private func createSystemInfo() -> SystemInfo {
        UIDevice.current.isBatteryMonitoringEnabled = true
        defer { UIDevice.current.isBatteryMonitoringEnabled = false }
        
        return SystemInfo(
            backgroundAppRefreshStatus: UIApplication.shared.backgroundRefreshStatus,
            deviceModel: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            batteryLevel: UIDevice.current.batteryLevel,
            batteryState: UIDevice.current.batteryState
        )
    }
    
    // Helper function to get available memory
    private func getAvailableMemory() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return Int64(info.resident_size)
        }
        
        return 0
    }
    
    override init() {
        super.init()
        setupMetricKit()
        startSystemMonitoring()
    }
    
    // MARK: - MetricKit Setup
    
    private func setupMetricKit() {
        metricManager = MXMetricManager.shared
        metricManager.add(self)
        isMetricKitEnabled = true
        logger.info("MetricKit integration enabled successfully")
    }
    
    // MARK: - Task Execution Tracking
    
    func recordTaskScheduling(identifier: String, scheduledAt: Date = Date()) {
        taskSchedulingTimes[identifier] = CFAbsoluteTimeGetCurrent()
        logger.debug("Recording task scheduling for: \(identifier)")
    }
    
    func recordTaskExecutionStart(identifier: String) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        taskExecutionStartTimes[identifier] = currentTime
        
        // Calculate scheduling latency if we have the scheduling time
        if let schedulingTime = taskSchedulingTimes[identifier] {
            let latency = currentTime - schedulingTime
            recordSchedulingLatency(identifier: identifier, latency: latency)
        }
        
        // Start performance monitoring for this task
        performanceMonitor.startMonitoring(for: identifier)
        systemResourceMonitor.startMonitoring(for: identifier)
        networkMonitor.startMonitoring(for: identifier)
        
        logger.debug("Recording task execution start for: \(identifier)")
    }
    
    func recordTaskExecutionEnd(identifier: String, success: Bool, error: Error? = nil) {
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration: TimeInterval
        
        if let startTime = taskExecutionStartTimes[identifier] {
            duration = endTime - startTime
            taskExecutionStartTimes.removeValue(forKey: identifier)
        } else {
            duration = 0
            logger.warning("No start time found for task: \(identifier)")
        }
        
        // Stop monitoring
        let performanceMetrics = performanceMonitor.stopMonitoring(for: identifier)
        let systemMetrics = systemResourceMonitor.stopMonitoring(for: identifier)
        let networkMetrics = networkMonitor.stopMonitoring(for: identifier)
        
        // Create comprehensive event with all metrics
        let event = createEnhancedTaskEvent(
            identifier: identifier,
            type: .taskExecutionCompleted,
            duration: duration,
            success: success,
            error: error,
            performanceMetrics: performanceMetrics,
            systemMetrics: systemMetrics,
            networkMetrics: networkMetrics
        )
        
        dataStore.recordEvent(event)
        taskSchedulingTimes.removeValue(forKey: identifier)
        
        logger.info("Recorded task execution completion for: \(identifier) - Success: \(success), Duration: \(String(format: "%.3f", duration))s")
    }
    
    func recordTaskExpiration(identifier: String) {
        if let startTime = taskExecutionStartTimes[identifier] {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            taskExecutionStartTimes.removeValue(forKey: identifier)
            
            let event = createEnhancedTaskEvent(
                identifier: identifier,
                type: .taskExpired,
                duration: duration,
                success: false,
                error: BackgroundTaskError.taskExpired
            )
            
            dataStore.recordEvent(event)
        }
        
        // Clean up monitoring
        performanceMonitor.stopMonitoring(for: identifier)
        systemResourceMonitor.stopMonitoring(for: identifier)
        networkMonitor.stopMonitoring(for: identifier)
        taskSchedulingTimes.removeValue(forKey: identifier)
        
        logger.info("Recorded task expiration for: \(identifier)")
    }
    
    // MARK: - Private Helper Methods
    
    private func recordSchedulingLatency(identifier: String, latency: TimeInterval) {
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: identifier,
            type: .taskExecutionStarted,
            timestamp: Date(),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: [
                "scheduling_latency": latency,
                "latency_category": categorizeLatency(latency)
            ],
            systemInfo: createSystemInfo()
        )
        
        dataStore.recordEvent(event)
        
        if latency > 10.0 { // Log high latency
            logger.warning("High scheduling latency detected: \(String(format: "%.3f", latency))s for task: \(identifier)")
        }
    }
    
    private func createEnhancedTaskEvent(
        identifier: String,
        type: BackgroundTaskEventType,
        duration: TimeInterval? = nil,
        success: Bool,
        error: Error? = nil,
        performanceMetrics: PerformanceMetrics? = nil,
        systemMetrics: SystemResourceMetrics? = nil,
        networkMetrics: NetworkMetrics? = nil
    ) -> BackgroundTaskEvent {
        
        var metadata: [String: Any] = [:]
        
        // Add performance metrics
        if let perf = performanceMetrics {
            metadata.merge(perf.toDictionary()) { _, new in new }
        }
        
        // Add system resource metrics
        if let system = systemMetrics {
            metadata.merge(system.toDictionary()) { _, new in new }
        }
        
        // Add network metrics
        if let network = networkMetrics {
            metadata.merge(network.toDictionary()) { _, new in new }
        }
        
        // Add error categorization
        if let error = error {
            let categorization = BGTaskSchedulerErrorCategorizer.categorize(error)
            metadata["error_category"] = categorization.category.rawValue
            metadata["error_severity"] = categorization.severity.rawValue
            metadata["error_code"] = categorization.code
            metadata["error_is_retryable"] = categorization.isRetryable
            metadata["error_suggested_action"] = categorization.suggestedAction
        }
        
        // Add duration categorization if available
        if let duration = duration {
            metadata["duration_category"] = categorizeDuration(duration)
        }
        
        return BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: identifier,
            type: type,
            timestamp: Date(),
            duration: duration,
            success: success,
            errorMessage: error?.localizedDescription,
            metadata: metadata,
            systemInfo: createSystemInfo()
        )
    }
    
    private func startSystemMonitoring() {
        // Start continuous system monitoring
        systemResourceMonitor.startContinuousMonitoring()
        networkMonitor.startContinuousMonitoring()
        
        logger.info("Started continuous system monitoring")
    }
    
    private func categorizeLatency(_ latency: TimeInterval) -> String {
        switch latency {
        case 0..<1: return "immediate"
        case 1..<5: return "fast"
        case 5..<30: return "moderate"
        case 30..<300: return "slow"
        default: return "very_slow"
        }
    }
    
    private func categorizeDuration(_ duration: TimeInterval) -> String {
        switch duration {
        case 0..<1: return "instant"
        case 1..<10: return "quick"
        case 10..<60: return "moderate"
        case 60..<300: return "long"
        default: return "extended"
        }
    }
    
    // MARK: - MXMetricManagerSubscriber
    
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            processMetricPayload(payload)
        }
    }
    
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            processDiagnosticPayload(payload)
        }
    }
    
    private func processMetricPayload(_ payload: MXMetricPayload) {
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "METRICKIT_METRICS",
            type: .initialization,
            timestamp: Date(),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: extractMetricKitData(from: payload),
            systemInfo: createSystemInfo()
        )
        
        dataStore.recordEvent(event)
        logger.info("Processed MetricKit payload with metrics data")
    }
    
    private func processDiagnosticPayload(_ payload: MXDiagnosticPayload) {
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "METRICKIT_DIAGNOSTICS",
            type: .initialization,
            timestamp: Date(),
            duration: nil,
            success: false,
            errorMessage: "Diagnostic data received",
            metadata: extractDiagnosticData(from: payload),
            systemInfo: createSystemInfo()
        )
        
        dataStore.recordEvent(event)
        logger.warning("Processed MetricKit diagnostic payload")
    }
    
    private func extractMetricKitData(from payload: MXMetricPayload) -> [String: Any] {
        var metadata: [String: Any] = [:]
        
        // CPU metrics
        if let cpuMetric = payload.cpuMetrics {
            metadata["cpu_total_time"] = cpuMetric.cumulativeCPUTime.value
            metadata["cpu_instructions"] = cpuMetric.cumulativeCPUInstructions.value
        }
        
        // Memory metrics
        if let memoryMetric = payload.memoryMetrics {
            metadata["memory_peak"] = memoryMetric.peakMemoryUsage.value
            let averageSuspended = memoryMetric.averageSuspendedMemory
            metadata["memory_average"] = averageSuspended.averageMeasurement.value
        }
        
        // Disk metrics
        if let diskMetric = payload.diskIOMetrics {
            metadata["disk_writes"] = diskMetric.cumulativeLogicalWrites.value
        }
        
        // Network metrics
        if let networkMetric = payload.networkTransferMetrics {
            metadata["network_wifi_up"] = networkMetric.cumulativeWifiUpload.value
            metadata["network_wifi_down"] = networkMetric.cumulativeWifiDownload.value
            metadata["network_cellular_up"] = networkMetric.cumulativeCellularUpload.value
            metadata["network_cellular_down"] = networkMetric.cumulativeCellularDownload.value
        }
        
        // Display metrics
        if let displayMetric = payload.displayMetrics, let averagePixelLuminance = displayMetric.averagePixelLuminance {
            metadata["display_apl"] = averagePixelLuminance.averageMeasurement.value
        }
        
        // Animation metrics
        if let animationMetric = payload.animationMetrics {
            metadata["animation_glitch_time"] = animationMetric.scrollHitchTimeRatio.value
        }
        
        // App launch metrics
        if let launchMetric = payload.applicationLaunchMetrics {
            if let timeToFirstDraw = launchMetric.histogrammedTimeToFirstDraw.bucketEnumerator.nextObject() {
                metadata["launch_time_to_first_draw"] = timeToFirstDraw
            }
        }
        
        // App responsiveness
        if let responsivenessMetric = payload.applicationResponsivenessMetrics {
            if let hangTime = responsivenessMetric.histogrammedApplicationHangTime.bucketEnumerator.nextObject() {
                metadata["responsiveness_hang_time"] = hangTime
            }
        }
        
        // Location metrics
        if let locationMetric = payload.locationActivityMetrics {
            metadata["location_best_accuracy_time"] = locationMetric.cumulativeBestAccuracyTime.value
            metadata["location_best_accuracy_for_navigation_time"] = locationMetric.cumulativeBestAccuracyForNavigationTime.value
            metadata["location_nearest_ten_meters_accuracy_time"] = locationMetric.cumulativeNearestTenMetersAccuracyTime.value
            metadata["location_hundred_meters_accuracy_time"] = locationMetric.cumulativeHundredMetersAccuracyTime.value
            metadata["location_kilometer_accuracy_time"] = locationMetric.cumulativeKilometerAccuracyTime.value
        }
        
        metadata["metrickit_time_range"] = "\(payload.timeStampBegin) - \(payload.timeStampEnd)"
        return metadata
    }
    
    private func extractDiagnosticData(from payload: MXDiagnosticPayload) -> [String: Any] {
        var metadata: [String: Any] = [:]
        
        // CPU exception diagnostics
        if let cpuExceptionDiagnostic = payload.cpuExceptionDiagnostics?.first {
            metadata["cpu_total_cpu_time"] = cpuExceptionDiagnostic.totalCPUTime.value
            metadata["cpu_total_sampled_time"] = cpuExceptionDiagnostic.totalSampledTime.value
        }
        
        // Disk write exception diagnostics
        if let diskExceptionDiagnostic = payload.diskWriteExceptionDiagnostics?.first {
            metadata["disk_writes_caused"] = diskExceptionDiagnostic.totalWritesCaused.value
        }
        
        // Hang diagnostics
        if let hangDiagnostic = payload.hangDiagnostics?.first {
            metadata["hang_duration"] = hangDiagnostic.hangDuration.value
        }
        
        // Crash diagnostics
        if let crashDiagnostic = payload.crashDiagnostics?.first {
            metadata["crash_exception_type"] = crashDiagnostic.exceptionType?.stringValue ?? "unknown"
            metadata["crash_exception_code"] = crashDiagnostic.exceptionCode?.intValue ?? 0
            metadata["crash_signal"] = crashDiagnostic.signal?.intValue ?? 0
            metadata["crash_termination_reason"] = crashDiagnostic.terminationReason ?? "unknown"
            metadata["crash_virtual_memory_region_info"] = crashDiagnostic.virtualMemoryRegionInfo ?? "unknown"
        }
        
        metadata["diagnostic_time_range"] = "\(payload.timeStampBegin) - \(payload.timeStampEnd)"
        return metadata
    }
}

// MARK: - Performance Metrics Collector

private class PerformanceMetricsCollector {
    private let logger = Logger(subsystem: "BackgroundTime", category: "PerformanceMetrics")
    private var activeMonitoring: [String: PerformanceMonitoringSession] = [:]
    
    func startMonitoring(for taskIdentifier: String) {
        let session = PerformanceMonitoringSession()
        session.start()
        activeMonitoring[taskIdentifier] = session
    }
    
    func stopMonitoring(for taskIdentifier: String) -> PerformanceMetrics? {
        guard let session = activeMonitoring.removeValue(forKey: taskIdentifier) else {
            return nil
        }
        return session.stop()
    }
}

private class PerformanceMonitoringSession {
    private var startTime: CFAbsoluteTime = 0
    private var startCPUTime: clock_t = 0
    private var peakMemory: Int64 = 0
    private let cpuInfoSize = MemoryLayout<processor_cpu_load_info>.stride * Int(HOST_CPU_LOAD_INFO)
    
    func start() {
        startTime = CFAbsoluteTimeGetCurrent()
        startCPUTime = clock()
        updatePeakMemory()
    }
    
    func stop() -> PerformanceMetrics {
        let endTime = CFAbsoluteTimeGetCurrent()
        let endCPUTime = clock()
        let duration = endTime - startTime
        let cpuTime = Double(endCPUTime - startCPUTime) / Double(CLOCKS_PER_SEC)
        
        updatePeakMemory()
        
        return PerformanceMetrics(
            duration: duration,
            cpuTime: cpuTime,
            cpuUsagePercentage: duration > 0 ? (cpuTime / duration) * 100 : 0,
            peakMemoryUsage: peakMemory,
            energyImpact: calculateEnergyImpact(cpuTime: cpuTime, duration: duration)
        )
    }
    
    private func updatePeakMemory() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            peakMemory = max(peakMemory, Int64(info.resident_size))
        }
    }
    
    private func calculateEnergyImpact(cpuTime: Double, duration: Double) -> EnergyImpact {
        let cpuRatio = duration > 0 ? cpuTime / duration : 0
        
        switch cpuRatio {
        case 0..<0.1: return .veryLow
        case 0.1..<0.3: return .low
        case 0.3..<0.6: return .moderate
        case 0.6..<0.8: return .high
        default: return .veryHigh
        }
    }
}

// MARK: - System Resource Monitor

private class SystemResourceMonitor {
    private let logger = Logger(subsystem: "BackgroundTime", category: "SystemResources")
    private var activeMonitoring: [String: SystemMonitoringSession] = [:]
    private var continuousMonitoringTimer: Timer?
    
    func startMonitoring(for taskIdentifier: String) {
        let session = SystemMonitoringSession()
        session.start()
        activeMonitoring[taskIdentifier] = session
    }
    
    func stopMonitoring(for taskIdentifier: String) -> SystemResourceMetrics? {
        guard let session = activeMonitoring.removeValue(forKey: taskIdentifier) else {
            return nil
        }
        return session.stop()
    }
    
    func startContinuousMonitoring() {
        continuousMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.logSystemResources()
        }
    }
    
    // Helper function to convert thermal state to string
    private class func thermalStateToString(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
    
    private func logSystemResources() {
        let metrics = getCurrentSystemMetrics()
        
        if metrics.availableMemoryPercentage < 10 {
            logger.warning("Low memory condition detected: \(Int(metrics.availableMemoryPercentage))% available")
        }
        
        if metrics.batteryLevel < 0.2 && !metrics.isCharging {
            logger.warning("Low battery condition: \(Int(metrics.batteryLevel * 100))%")
        }
        
        if metrics.thermalState == .critical || metrics.thermalState == .serious {
            logger.warning("High thermal state: \(Self.thermalStateToString(metrics.thermalState))")
        }
    }
    
    private func getCurrentSystemMetrics() -> SystemResourceMetrics {
        return SystemResourceMetrics(
            batteryLevel: getBatteryLevel(),
            isCharging: getBatteryState() == .charging,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalState: ProcessInfo.processInfo.thermalState,
            availableMemoryPercentage: getAvailableMemoryPercentage(),
            diskSpaceAvailable: getAvailableDiskSpace()
        )
    }
    
    private func getBatteryLevel() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        defer { UIDevice.current.isBatteryMonitoringEnabled = false }
        return UIDevice.current.batteryLevel
    }
    
    private func getBatteryState() -> UIDevice.BatteryState {
        UIDevice.current.isBatteryMonitoringEnabled = true
        defer { UIDevice.current.isBatteryMonitoringEnabled = false }
        return UIDevice.current.batteryState
    }
    
    private func getAvailableMemoryPercentage() -> Double {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size)
            let totalMemory = Double(physicalMemory)
            return ((totalMemory - usedMemory) / totalMemory) * 100
        }
        
        return 50.0 // Default fallback
    }
    
    private func getAvailableDiskSpace() -> Int64 {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber
            return freeSpace?.int64Value ?? 0
        } catch {
            return 0
        }
    }
}

private class SystemMonitoringSession {
    private var startMetrics: SystemResourceMetrics?
    
    func start() {
        startMetrics = getCurrentSystemMetrics()
    }
    
    func stop() -> SystemResourceMetrics {
        return getCurrentSystemMetrics()
    }
    
    private func getCurrentSystemMetrics() -> SystemResourceMetrics {
        return SystemResourceMetrics(
            batteryLevel: getBatteryLevel(),
            isCharging: getBatteryState() == .charging,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalState: ProcessInfo.processInfo.thermalState,
            availableMemoryPercentage: getAvailableMemoryPercentage(),
            diskSpaceAvailable: getAvailableDiskSpace()
        )
    }
    
    private func getBatteryLevel() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        defer { UIDevice.current.isBatteryMonitoringEnabled = false }
        return UIDevice.current.batteryLevel
    }
    
    private func getBatteryState() -> UIDevice.BatteryState {
        UIDevice.current.isBatteryMonitoringEnabled = true
        defer { UIDevice.current.isBatteryMonitoringEnabled = false }
        return UIDevice.current.batteryState
    }
    
    private func getAvailableMemoryPercentage() -> Double {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size)
            let totalMemory = Double(physicalMemory)
            return ((totalMemory - usedMemory) / totalMemory) * 100
        }
        
        return 50.0 // Default fallback
    }
    
    private func getAvailableDiskSpace() -> Int64 {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber
            return freeSpace?.int64Value ?? 0
        } catch {
            return 0
        }
    }
}

// MARK: - Network Metrics Collector

private class NetworkMetricsCollector {
    private let logger = Logger(subsystem: "BackgroundTime", category: "NetworkMetrics")
    private var activeMonitoring: [String: NetworkMonitoringSession] = [:]
    
    func startMonitoring(for taskIdentifier: String) {
        let session = NetworkMonitoringSession()
        session.start()
        activeMonitoring[taskIdentifier] = session
    }
    
    func stopMonitoring(for taskIdentifier: String) -> NetworkMetrics? {
        guard let session = activeMonitoring.removeValue(forKey: taskIdentifier) else {
            return nil
        }
        return session.stop()
    }
    
    func startContinuousMonitoring() {
        // Network monitoring would typically involve more complex setup
        // For now, we'll track basic connectivity
        logger.info("Started continuous network monitoring")
    }
}

private class NetworkMonitoringSession {
    private var startTime: CFAbsoluteTime = 0
    private var requestCount = 0
    private var totalBytesTransferred: Int64 = 0
    private var connectionFailures = 0
    
    func start() {
        startTime = CFAbsoluteTimeGetCurrent()
        requestCount = 0
        totalBytesTransferred = 0
        connectionFailures = 0
    }
    
    func stop() -> NetworkMetrics {
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        return NetworkMetrics(
            requestCount: requestCount,
            totalBytesTransferred: totalBytesTransferred,
            connectionFailures: connectionFailures,
            averageLatency: duration / Double(max(requestCount, 1)),
            connectionReliability: requestCount > 0 ? Double(requestCount - connectionFailures) / Double(requestCount) : 1.0
        )
    }
    
    func recordRequest(bytesTransferred: Int64, success: Bool) {
        requestCount += 1
        totalBytesTransferred += bytesTransferred
        if !success {
            connectionFailures += 1
        }
    }
}
