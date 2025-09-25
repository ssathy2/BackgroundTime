//
//  BGTaskSwizzler.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Foundation
import BackgroundTasks
import os.log
import UIKit

// MARK: - BGTask Method Swizzling

class BGTaskSwizzler {
    private static let logger = Logger(subsystem: "BackgroundTime", category: "TaskSwizzler")
    static var taskStartTimes: [String: Date] = [:]
    static let taskQueue = DispatchQueue(label: "BackgroundTime.TaskSwizzler", attributes: .concurrent)
    
    static func swizzleTaskMethods() {
        swizzleSetTaskCompletedMethod()
        logger.info("BGTask methods swizzled successfully")
    }
    
    static func swizzleTaskCompletion(for task: BGTask, startTime: Date) {
        taskQueue.async(flags: .barrier) {
            taskStartTimes[task.identifier] = startTime
        }
        
        // Set up expiration handler tracking
        let originalExpirationHandler = task.expirationHandler
        task.expirationHandler = {
            let endTime = Date()
            let duration = taskQueue.sync {
                taskStartTimes[task.identifier].map { endTime.timeIntervalSince($0) }
            }
            
            let event = BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: task.identifier,
                type: .taskExpired,
                timestamp: endTime,
                duration: duration,
                success: false,
                errorMessage: "Task expired before completion",
                metadata: ["expiration_handler": "true"],
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
            
            // Clean up start time
            taskQueue.async(flags: .barrier) {
                taskStartTimes.removeValue(forKey: task.identifier)
            }
            
            // Call original expiration handler
            originalExpirationHandler?()
        }
    }
    
    private static func swizzleSetTaskCompletedMethod() {
        let originalSelector = #selector(BGTask.setTaskCompleted(success:))
        let swizzledSelector = #selector(BGTask.bt_setTaskCompleted(success:))
        
        guard let originalMethod = class_getInstanceMethod(BGTask.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(BGTask.self, swizzledSelector) else {
            logger.error("Failed to get methods for setTaskCompleted swizzling")
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

// MARK: - BGTask Extension

extension BGTask {
    @objc dynamic func bt_setTaskCompleted(success: Bool) {
        let endTime = Date()
        
        let duration = BGTaskSwizzler.taskQueue.sync {
            BGTaskSwizzler.taskStartTimes[self.identifier].map { endTime.timeIntervalSince($0) }
        }
        
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: self.identifier,
            type: .taskExecutionCompleted,
            timestamp: endTime,
            duration: duration,
            success: success,
            errorMessage: success ? nil : "Task completed with failure",
            metadata: [
                "completion_success": success,
                "task_type": String(describing: type(of: self))
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
        BackgroundTaskDataStore.shared.recordEvent(event)
        
        // Clean up start time
        BGTaskSwizzler.taskQueue.async(flags: .barrier) {
            BGTaskSwizzler.taskStartTimes.removeValue(forKey: self.identifier)
        }
        
        // Call original method
        self.bt_setTaskCompleted(success: success)
    }
}
