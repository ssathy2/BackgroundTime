//
//  BGTaskSchedulerSwizzler.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Foundation
import BackgroundTasks
import os.log
import UIKit

// MARK: - BGTaskScheduler Method Swizzling
@MainActor
final class BGTaskSchedulerSwizzler {
    private static let logger = Logger(subsystem: "BackgroundTime", category: "Swizzler")
    
    // Add a flag to track if swizzling has been performed
    private static var hasSwizzled = false

    static func swizzleSchedulerMethods() {
        guard !hasSwizzled else {
            return
        }
        
        // Swizzle submit method
        swizzleSubmitMethod()
        
        // Swizzle cancel methods
        swizzleCancelMethods()
        
        // Swizzle register method
        swizzleRegisterMethod()
        
        hasSwizzled = true
    }
    
    // Add a test method to verify swizzling worked
    static func testSwizzling() {
        let registerSelector = #selector(BGTaskScheduler.register(forTaskWithIdentifier:using:launchHandler:))
        let swizzledSelector = #selector(BGTaskScheduler.bt_register(forTaskWithIdentifier:using:launchHandler:))
        
        let originalMethod = class_getInstanceMethod(BGTaskScheduler.self, registerSelector)
        let swizzledMethod = class_getInstanceMethod(BGTaskScheduler.self, swizzledSelector)
        
        logger.info("Swizzling test - Original: \(originalMethod != nil), Swizzled: \(swizzledMethod != nil), Complete: \(hasSwizzled)")
    }
    
    private static func swizzleSubmitMethod() {
        let originalSelector = #selector(BGTaskScheduler.submit(_:))
        let swizzledSelector = #selector(BGTaskScheduler.bt_submit(_:))
        
        guard let originalMethod = class_getInstanceMethod(BGTaskScheduler.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(BGTaskScheduler.self, swizzledSelector) else {
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    private static func swizzleCancelMethods() {
        // Cancel with identifier
        let cancelSelector = #selector(BGTaskScheduler.cancel(taskRequestWithIdentifier:))
        let swizzledCancelSelector = #selector(BGTaskScheduler.bt_cancel(taskRequestWithIdentifier:))
        
        guard let cancelMethod = class_getInstanceMethod(BGTaskScheduler.self, cancelSelector),
              let swizzledCancelMethod = class_getInstanceMethod(BGTaskScheduler.self, swizzledCancelSelector) else {
            return
        }
        
        method_exchangeImplementations(cancelMethod, swizzledCancelMethod)
        
        // Cancel all tasks
        let cancelAllSelector = #selector(BGTaskScheduler.cancelAllTaskRequests)
        let swizzledCancelAllSelector = #selector(BGTaskScheduler.bt_cancelAllTaskRequests)
        
        guard let cancelAllMethod = class_getInstanceMethod(BGTaskScheduler.self, cancelAllSelector),
              let swizzledCancelAllMethod = class_getInstanceMethod(BGTaskScheduler.self, swizzledCancelAllSelector) else {
            return
        }
        
        method_exchangeImplementations(cancelAllMethod, swizzledCancelAllMethod)
    }
    
    private static func swizzleRegisterMethod() {
        let registerSelector = #selector(BGTaskScheduler.register(forTaskWithIdentifier:using:launchHandler:))
        let swizzledSelector = #selector(BGTaskScheduler.bt_register(forTaskWithIdentifier:using:launchHandler:))
        
        guard let registerMethod = class_getInstanceMethod(BGTaskScheduler.self, registerSelector),
              let swizzledRegisterMethod = class_getInstanceMethod(BGTaskScheduler.self, swizzledSelector) else {
            return
        }
        
        method_exchangeImplementations(registerMethod, swizzledRegisterMethod)
    }
}

// MARK: - BGTaskScheduler Extensions

extension BGTaskScheduler {
    @objc dynamic func bt_submit(_ taskRequest: BGTaskRequest) throws {
        let startTime = Date()
        
        // Capture system info on main thread if needed
        let systemInfo: SystemInfo
        if Thread.isMainThread {
            systemInfo = SystemInfo(
                backgroundAppRefreshStatus: UIApplication.shared.backgroundRefreshStatus,
                deviceModel: UIDevice.current.model,
                systemVersion: UIDevice.current.systemVersion,
                lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                batteryLevel: UIDevice.current.batteryLevel,
                batteryState: UIDevice.current.batteryState
            )
        } else {
            systemInfo = DispatchQueue.main.sync {
                SystemInfo(
                    backgroundAppRefreshStatus: UIApplication.shared.backgroundRefreshStatus,
                    deviceModel: UIDevice.current.model,
                    systemVersion: UIDevice.current.systemVersion,
                    lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                    batteryLevel: UIDevice.current.batteryLevel,
                    batteryState: UIDevice.current.batteryState
                )
            }
        }
        
        // Record the scheduling attempt
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: taskRequest.identifier,
            type: .taskScheduled,
            timestamp: startTime,
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: [
                "earliestBeginDate": taskRequest.earliestBeginDate?.iso8601String ?? "none",
                "requiresNetworkConnectivity": String(taskRequest is BGAppRefreshTaskRequest ? false : (taskRequest as? BGProcessingTaskRequest)?.requiresNetworkConnectivity ?? false),
                "requiresExternalPower": String(taskRequest is BGAppRefreshTaskRequest ? false : (taskRequest as? BGProcessingTaskRequest)?.requiresExternalPower ?? false)
            ],
            systemInfo: systemInfo
        )
        
        // Try to submit the task and handle any errors
        do {
            // After method swizzling, bt_submit is now the original submit method
            try self.bt_submit(taskRequest)
            BackgroundTaskDataStore.shared.recordEvent(event)
        } catch {
            // Record the failure
            let failureEvent = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: taskRequest.identifier,
                type: .taskFailed,
                timestamp: Date(),
                duration: Date().timeIntervalSince(startTime),
                success: false,
                errorMessage: error.localizedDescription,
                metadata: event.metadata,
                systemInfo: systemInfo
            )
            BackgroundTaskDataStore.shared.recordEvent(failureEvent)
            throw error
        }
    }
    
    @objc dynamic func bt_cancel(taskRequestWithIdentifier identifier: String) {
        // Capture system info on main thread if needed
        let systemInfo: SystemInfo
        if Thread.isMainThread {
            systemInfo = SystemInfo(
                backgroundAppRefreshStatus: UIApplication.shared.backgroundRefreshStatus,
                deviceModel: UIDevice.current.model,
                systemVersion: UIDevice.current.systemVersion,
                lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                batteryLevel: UIDevice.current.batteryLevel,
                batteryState: UIDevice.current.batteryState
            )
        } else {
            systemInfo = DispatchQueue.main.sync {
                SystemInfo(
                    backgroundAppRefreshStatus: UIApplication.shared.backgroundRefreshStatus,
                    deviceModel: UIDevice.current.model,
                    systemVersion: UIDevice.current.systemVersion,
                    lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                    batteryLevel: UIDevice.current.batteryLevel,
                    batteryState: UIDevice.current.batteryState
                )
            }
        }
        
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: identifier,
            type: .taskCancelled,
            timestamp: Date(),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: ["reason": "manual_cancellation"],
            systemInfo: systemInfo
        )
        
        BackgroundTaskDataStore.shared.recordEvent(event)
        
        // After method swizzling, bt_cancel is now the original cancel method
        self.bt_cancel(taskRequestWithIdentifier: identifier)
    }
    
    @objc dynamic func bt_cancelAllTaskRequests() {
        // Capture system info on main thread if needed
        let systemInfo: SystemInfo
        if Thread.isMainThread {
            systemInfo = SystemInfo(
                backgroundAppRefreshStatus: UIApplication.shared.backgroundRefreshStatus,
                deviceModel: UIDevice.current.model,
                systemVersion: UIDevice.current.systemVersion,
                lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                batteryLevel: UIDevice.current.batteryLevel,
                batteryState: UIDevice.current.batteryState
            )
        } else {
            systemInfo = DispatchQueue.main.sync {
                SystemInfo(
                    backgroundAppRefreshStatus: UIApplication.shared.backgroundRefreshStatus,
                    deviceModel: UIDevice.current.model,
                    systemVersion: UIDevice.current.systemVersion,
                    lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                    batteryLevel: UIDevice.current.batteryLevel,
                    batteryState: UIDevice.current.batteryState
                )
            }
        }
        
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "ALL_TASKS",
            type: .taskCancelled,
            timestamp: Date(),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: ["reason": "cancel_all_tasks"],
            systemInfo: systemInfo
        )
        
        BackgroundTaskDataStore.shared.recordEvent(event)
        
        // After method swizzling, bt_cancelAllTaskRequests is now the original method
        self.bt_cancelAllTaskRequests()
    }
    
    @objc dynamic func bt_register(forTaskWithIdentifier identifier: String, using queue: DispatchQueue?, launchHandler: @escaping (BGTask) -> Void) -> Bool {
        // Create a wrapped launch handler that tracks execution
        let wrappedLaunchHandler: (BGTask) -> Void = { task in
            let startTime = Date()
            
            // Capture system info safely
            let systemInfo: SystemInfo
            if Thread.isMainThread {
                systemInfo = SystemInfo(
                    backgroundAppRefreshStatus: UIApplication.shared.backgroundRefreshStatus,
                    deviceModel: UIDevice.current.model,
                    systemVersion: UIDevice.current.systemVersion,
                    lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                    batteryLevel: UIDevice.current.batteryLevel,
                    batteryState: UIDevice.current.batteryState
                )
            } else {
                systemInfo = DispatchQueue.main.sync {
                    SystemInfo(
                        backgroundAppRefreshStatus: UIApplication.shared.backgroundRefreshStatus,
                        deviceModel: UIDevice.current.model,
                        systemVersion: UIDevice.current.systemVersion,
                        lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                        batteryLevel: UIDevice.current.batteryLevel,
                        batteryState: UIDevice.current.batteryState
                    )
                }
            }
            
            // Record task execution start
            let startEvent = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: identifier,
                type: .taskExecutionStarted,
                timestamp: startTime,
                duration: nil,
                success: true,
                errorMessage: nil,
                metadata: [
                    "task_type": String(describing: type(of: task)),
                    "auto_tracked": "true",
                    "tracking_method": "swizzling"
                ],
                systemInfo: systemInfo
            )
            BackgroundTaskDataStore.shared.recordEvent(startEvent)
            
            // Set up automatic completion tracking
            BGTaskSwizzler.swizzleTaskCompletion(for: task, startTime: startTime)
            
            // Notify MetricCollectionManager for performance tracking
            Task { @MainActor in
                MetricCollectionManager.shared.recordTaskExecutionStart(identifier: identifier)
            }
            
            // Wrap the original expiration handler to ensure proper cleanup
            let originalExpirationHandler = task.expirationHandler
            task.expirationHandler = {
                // Record expiration event
                Task { @MainActor in
                    MetricCollectionManager.shared.recordTaskExpiration(identifier: identifier)
                }
                
                // Call original handler if it exists
                originalExpirationHandler?()
            }
            
            // Call the original launch handler
            launchHandler(task)
        }
        
        // Call the original register method (after swizzling, bt_register points to the original implementation)
        let result = self.bt_register(forTaskWithIdentifier: identifier, using: queue, launchHandler: wrappedLaunchHandler)
        
        // Record registration attempt
        Task { @MainActor in
            let systemInfo = SystemInfo(
                backgroundAppRefreshStatus: UIApplication.shared.backgroundRefreshStatus,
                deviceModel: UIDevice.current.model,
                systemVersion: UIDevice.current.systemVersion,
                lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                batteryLevel: UIDevice.current.batteryLevel,
                batteryState: UIDevice.current.batteryState
            )
            
            let registrationEvent = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: identifier,
                type: result ? .taskScheduled : .taskFailed,
                timestamp: Date(),
                duration: nil,
                success: result,
                errorMessage: result ? nil : "Task registration failed",
                metadata: [
                    "registration_success": String(result),
                    "auto_tracked": "true",
                    "tracking_method": "swizzling"
                ],
                systemInfo: systemInfo
            )
            BackgroundTaskDataStore.shared.recordEvent(registrationEvent)
        }
        
        return result
    }
}

// MARK: - Date Extension

extension Date {
    public var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
