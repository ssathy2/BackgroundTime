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

class BGTaskSchedulerSwizzler {
    private static let logger = Logger(subsystem: "BackgroundTime", category: "Swizzler")
    private static var isSwizzled = false
    
    static func swizzleSchedulerMethods() {
        guard !isSwizzled else { return }
        
        // Swizzle submit method
        swizzleSubmitMethod()
        
        // Swizzle cancel methods
        swizzleCancelMethods()
        
        // Swizzle register method
        swizzleRegisterMethod()
        
        isSwizzled = true
        logger.info("BGTaskScheduler methods swizzled successfully")
    }
    
    private static func swizzleSubmitMethod() {
        let originalSelector = #selector(BGTaskScheduler.submit(_:))
        let swizzledSelector = #selector(BGTaskScheduler.bt_submit(_:))
        
        guard let originalMethod = class_getInstanceMethod(BGTaskScheduler.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(BGTaskScheduler.self, swizzledSelector) else {
            logger.error("Failed to get methods for submit swizzling")
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
            logger.error("Failed to get methods for cancel swizzling")
            return
        }
        
        method_exchangeImplementations(cancelMethod, swizzledCancelMethod)
        
        // Cancel all tasks
        let cancelAllSelector = #selector(BGTaskScheduler.cancelAllTaskRequests)
        let swizzledCancelAllSelector = #selector(BGTaskScheduler.bt_cancelAllTaskRequests)
        
        guard let cancelAllMethod = class_getInstanceMethod(BGTaskScheduler.self, cancelAllSelector),
              let swizzledCancelAllMethod = class_getInstanceMethod(BGTaskScheduler.self, swizzledCancelAllSelector) else {
            logger.error("Failed to get methods for cancelAll swizzling")
            return
        }
        
        method_exchangeImplementations(cancelAllMethod, swizzledCancelAllMethod)
    }
    
    private static func swizzleRegisterMethod() {
        let registerSelector = #selector(BGTaskScheduler.register(forTaskWithIdentifier:using:launchHandler:))
        let swizzledRegisterSelector = #selector(BGTaskScheduler.bt_register(forTaskWithIdentifier:using:launchHandler:))
        
        guard let registerMethod = class_getInstanceMethod(BGTaskScheduler.self, registerSelector),
              let swizzledRegisterMethod = class_getInstanceMethod(BGTaskScheduler.self, swizzledRegisterSelector) else {
            logger.error("Failed to get methods for register swizzling")
            return
        }
        
        method_exchangeImplementations(registerMethod, swizzledRegisterMethod)
    }
}

// MARK: - BGTaskScheduler Extensions

extension BGTaskScheduler {
    @objc dynamic func bt_submit(_ taskRequest: BGTaskRequest) throws {
        let startTime = Date()
        
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
                "requiresNetworkConnectivity": taskRequest is BGAppRefreshTaskRequest ? false : (taskRequest as? BGProcessingTaskRequest)?.requiresNetworkConnectivity ?? false,
                "requiresExternalPower": taskRequest is BGAppRefreshTaskRequest ? false : (taskRequest as? BGProcessingTaskRequest)?.requiresExternalPower ?? false
            ],
            systemInfo: SystemInfo(
                backgroundAppRefreshStatus: UIApplication.shared.backgroundRefreshStatus,
                deviceModel: UIDevice.current.model,
                systemVersion: UIDevice.current.systemVersion,
                lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                batteryLevel: UIDevice.current.batteryLevel,
                batteryState: UIDevice.current.batteryState
            )
        )
        
        // Try to submit the task and handle any errors
        do {
            try self.bt_submit(taskRequest) // Call original method
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
                systemInfo: event.systemInfo
            )
            BackgroundTaskDataStore.shared.recordEvent(failureEvent)
            throw error
        }
    }
    
    @objc dynamic func bt_cancel(taskRequestWithIdentifier identifier: String) {
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: identifier,
            type: .taskCancelled,
            timestamp: Date(),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: ["reason": "manual_cancellation"],
            systemInfo: SystemInfo(
                backgroundAppRefreshStatus: UIApplication.shared.backgroundRefreshStatus,
                deviceModel: UIDevice.current.model,
                systemVersion: UIDevice.current.systemVersion,
                lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                batteryLevel: UIDevice.current.batteryLevel,
                batteryState: UIDevice.current.batteryState
            )
        )
        
        BackgroundTaskDataStore.shared.recordEvent(event)
        self.bt_cancel(taskRequestWithIdentifier: identifier) // Call original method
    }
    
    @objc dynamic func bt_cancelAllTaskRequests() {
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "ALL_TASKS",
            type: .taskCancelled,
            timestamp: Date(),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: ["reason": "cancel_all_tasks"],
            systemInfo: SystemInfo(
                backgroundAppRefreshStatus: UIApplication.shared.backgroundRefreshStatus,
                deviceModel: UIDevice.current.model,
                systemVersion: UIDevice.current.systemVersion,
                lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                batteryLevel: UIDevice.current.batteryLevel,
                batteryState: UIDevice.current.batteryState
            )
        )
        
        BackgroundTaskDataStore.shared.recordEvent(event)
        self.bt_cancelAllTaskRequests() // Call original method
    }
    
    @objc dynamic func bt_register(forTaskWithIdentifier identifier: String, using queue: DispatchQueue?, launchHandler: @escaping (BGTask) -> Void) -> Bool {
        // Create a wrapped launch handler that tracks execution
        let wrappedLaunchHandler: (BGTask) -> Void = { task in
            let startTime = Date()
            
            // Record task execution start
            let startEvent = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: identifier,
                type: .taskExecutionStarted,
                timestamp: startTime,
                duration: nil,
                success: true,
                errorMessage: nil,
                metadata: ["task_type": String(describing: type(of: task))],
                systemInfo: SystemInfo(
                    backgroundAppRefreshStatus: UIApplication.shared.backgroundRefreshStatus,
                    deviceModel: UIDevice.current.model,
                    systemVersion: UIDevice.current.systemVersion,
                    lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                    batteryLevel: UIDevice.current.batteryLevel,
                    batteryState: UIDevice.current.batteryState
                )
            )
            BackgroundTaskDataStore.shared.recordEvent(startEvent)
            
            // Swizzle the task's setTaskCompleted method
            BGTaskSwizzler.swizzleTaskCompletion(for: task, startTime: startTime)
            
            // Call the original launch handler
            launchHandler(task)
        }
        
        return self.bt_register(forTaskWithIdentifier: identifier, using: queue, launchHandler: wrappedLaunchHandler)
    }
}

// MARK: - Date Extension

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
