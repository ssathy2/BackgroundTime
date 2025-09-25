//
//  BGTaskSwizzler.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/25/25.
//

import Foundation
import BackgroundTasks
import UIKit
import os.log

// MARK: - BGTask Method Swizzling

@objc class BGTaskSwizzler: NSObject {
    private static let logger = Logger(subsystem: "BackgroundTime", category: "TaskSwizzler")
    private static let dataStore = BackgroundTaskDataStore.shared
    private static var swizzlingCompleted = false
    private static let swizzlingQueue = DispatchQueue(label: "BackgroundTime.TaskSwizzling", qos: .utility)
    private static var taskStartTimes: [String: Date] = [:]
    private static let taskTimesQueue = DispatchQueue(label: "BackgroundTime.TaskTimes", attributes: .concurrent)
    
    @objc static func swizzleTaskMethods() {
        swizzlingQueue.sync {
            guard !swizzlingCompleted else {
                logger.warning("BGTask swizzling already completed")
                return
            }
            
            // Get BGTask classes
            guard let appRefreshTaskClass = NSClassFromString("BGAppRefreshTask"),
                  let processingTaskClass = NSClassFromString("BGProcessingTask") else {
                logger.error("Failed to get BGTask classes")
                return
            }
            
            // Swizzle setTaskCompleted for both task types
            swizzleSetTaskCompleted(in: appRefreshTaskClass)
            swizzleSetTaskCompleted(in: processingTaskClass)
            
            // Hook into task execution start by swizzling the task handlers
            setupTaskExecutionHooks()
            
            swizzlingCompleted = true
            logger.info("BGTask method swizzling completed successfully")
        }
    }
    
    // MARK: - Task Execution Tracking
    
    @objc static func recordTaskExecutionStart(for task: BGTask) {
        taskTimesQueue.async(flags: .barrier) {
            taskStartTimes[task.identifier] = Date()
        }
        
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: task.identifier,
            type: .taskExecutionStarted,
            timestamp: Date(),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: [
                "task_type": String(describing: type(of: task)),
                "expiration_handler_set": task.expirationHandler != nil
            ],
            systemInfo: SystemInfo.current()
        )
        
        dataStore.recordEvent(event)
        logger.info("Recorded task execution start for: \(task.identifier)")
    }
    
    @objc static func recordTaskExpiration(for task: BGTask) {
        var duration: TimeInterval?
        
        taskTimesQueue.sync {
            if let startTime = taskStartTimes[task.identifier] {
                duration = Date().timeIntervalSince(startTime)
            }
        }
        
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: task.identifier,
            type: .taskExpired,
            timestamp: Date(),
            duration: duration,
            success: false,
            errorMessage: "Task expired before completion",
            metadata: [
                "task_type": String(describing: type(of: task))
            ],
            systemInfo: SystemInfo.current()
        )
        
        dataStore.recordEvent(event)
        logger.warning("Recorded task expiration for: \(task.identifier)")
    }
    
    // MARK: - Swizzled Methods
    
    @objc func swizzled_setTaskCompleted(success: Bool) {
        // Get task identifier from the instance
        let task = self as! BGTask
        let identifier = task.identifier
        
        var duration: TimeInterval?
        BGTaskSwizzler.taskTimesQueue.sync {
            if let startTime = BGTaskSwizzler.taskStartTimes[identifier] {
                duration = Date().timeIntervalSince(startTime)
                BGTaskSwizzler.taskStartTimes.removeValue(forKey: identifier)
            }
        }
        
        // Call original implementation
        let originalSelector = #selector(BGTask.setTaskCompleted(success:))
        let originalMethod = class_getInstanceMethod(type(of: task), originalSelector)
        let originalImplementation = method_getImplementation(originalMethod!)
        
        typealias SetTaskCompletedFunction = @convention(c) (AnyObject, Selector, Bool) -> Void
        let originalFunction = unsafeBitCast(originalImplementation, to: SetTaskCompletedFunction.self)
        
        originalFunction(self, originalSelector, success)
        
        // Record the completion event
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: identifier,
            type: .taskExecutionCompleted,
            timestamp: Date(),
            duration: duration,
            success: success,
            errorMessage: success ? nil : "Task completed with failure",
            metadata: [
                "task_type": String(describing: type(of: task)),
                "completion_success": success
            ],
            systemInfo: SystemInfo.current()
        )
        
        BGTaskSwizzler.dataStore.recordEvent(event)
        BGTaskSwizzler.logger.info("Recorded task completion for: \(identifier) with success: \(success)")
    }
    
    // MARK: - Helper Methods
    
    private static func swizzleSetTaskCompleted(in taskClass: AnyClass) {
        guard let originalMethod = class_getInstanceMethod(taskClass, #selector(BGTask.setTaskCompleted(success:))),
              let swizzledMethod = class_getInstanceMethod(BGTaskSwizzler.self, #selector(BGTaskSwizzler.swizzled_setTaskCompleted(success:))) else {
            logger.error("Failed to get setTaskCompleted methods for swizzling")
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
        logger.info("Successfully swizzled setTaskCompleted for: \(taskClass)")
    }
    
    private static func setupTaskExecutionHooks() {
        // This would be used with BGTaskScheduler.shared.register methods
        // Since we can't easily swizzle the register methods themselves,
        // we'll provide a wrapper that apps can use
        logger.info("Task execution hooks setup completed")
    }
}

// MARK: - Task Handler Wrapper

public class BackgroundTaskHandler {
    private let originalHandler: (BGTask) -> Void
    private let taskIdentifier: String
    
    public init(taskIdentifier: String, handler: @escaping (BGTask) -> Void) {
        self.taskIdentifier = taskIdentifier
        self.originalHandler = handler
    }
    
    public func wrappedHandler(_ task: BGTask) {
        // Record execution start
        BGTaskSwizzler.recordTaskExecutionStart(for: task)
        
        // Set up expiration handler wrapper
        let originalExpirationHandler = task.expirationHandler
        task.expirationHandler = {
            BGTaskSwizzler.recordTaskExpiration(for: task)
            originalExpirationHandler?()
        }
        
        // Call original handler
        originalHandler(task)
    }
}

// MARK: - Public API Extensions

public extension BGTaskScheduler {
    /// Register a background task handler with BackgroundTime instrumentation
    func registerBackgroundTime(
        forTaskWithIdentifier identifier: String,
        using queue: DispatchQueue? = nil,
        launchHandler: @escaping (BGTask) -> Void
    ) -> Bool {
        let handler = BackgroundTaskHandler(taskIdentifier: identifier, handler: launchHandler)
        return self.register(forTaskWithIdentifier: identifier, using: queue, launchHandler: handler.wrappedHandler)
    }
}

// MARK: - System Info Extension

private extension SystemInfo {
    static func current() -> SystemInfo {
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
}
