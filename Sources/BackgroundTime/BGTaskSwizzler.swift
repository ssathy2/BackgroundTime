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

// MARK: - Task Start Times Actor

actor TaskStartTimesManager {
    private(set) var taskStartTimes: [String: Date] = [:]
    
    func setStartTime(_ time: Date, for identifier: String) {
        taskStartTimes[identifier] = time
    }
    
    func getStartTime(for identifier: String) -> Date? {
        return taskStartTimes[identifier]
    }
    
    func removeStartTime(for identifier: String) {
        taskStartTimes.removeValue(forKey: identifier)
    }
}

// MARK: - BGTask Method Swizzling
@MainActor
final class BGTaskSwizzler: Sendable {
    
    private static let logger = Logger(subsystem: "BackgroundTime", category: "TaskSwizzler")
    private(set) static var taskStartTimesManager = TaskStartTimesManager()
    
    static func swizzleTaskMethods() {
        swizzleSetTaskCompletedMethod()
        logger.info("BGTask methods swizzled successfully")
    }
    
    static func resetTaskStartTimesManager() {
        taskStartTimesManager = .init()
    }
    
    nonisolated static func swizzleTaskCompletion(for task: BGTask, startTime: Date) {
        let taskIdentifier = task.identifier
        Task { @Sendable in
            await taskStartTimesManager.setStartTime(startTime, for: taskIdentifier)
        }
        
        // Set up expiration handler tracking
        nonisolated(unsafe) let originalExpirationHandler = task.expirationHandler
        
        task.expirationHandler = { @Sendable in
            let endTime = Date()
            
            Task { @Sendable in
                let duration: TimeInterval? = await {
                    if let startTime = await taskStartTimesManager.getStartTime(for: taskIdentifier) {
                        return endTime.timeIntervalSince(startTime)
                    }
                    return nil
                }()
                
                let event = await BackgroundTaskEvent(
                    id: UUID(),
                    taskIdentifier: taskIdentifier,
                    type: .taskExpired,
                    timestamp: endTime,
                    duration: duration,
                    success: false,
                    errorMessage: "Task expired before completion",
                    metadata: ["expiration_handler": "true"],
                    systemInfo: SystemInfo(
                        backgroundAppRefreshStatus: await UIApplication.shared.backgroundRefreshStatus,
                        deviceModel: UIDevice.current.model,
                        systemVersion: UIDevice.current.systemVersion,
                        lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                        batteryLevel: UIDevice.current.batteryLevel,
                        batteryState: UIDevice.current.batteryState
                    )
                )
                BackgroundTaskDataStore.shared.recordEvent(event)
                
                // Clean up start time
                await taskStartTimesManager.removeStartTime(for: taskIdentifier)
            }
            
            // Call original expiration handler - we've already captured it safely with nonisolated(unsafe)
            if let originalExpirationHandler = originalExpirationHandler {
                // Since expiration handlers are typically main actor isolated,
                // we need to call them on the main actor
                Task { @MainActor in
                    originalExpirationHandler()
                }
            }
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
        let taskIdentifier = self.identifier
        let taskType = String(describing: type(of: self))
        
        Task { @Sendable in
            let duration: TimeInterval? = await {
                if let startTime = await BGTaskSwizzler.taskStartTimesManager.getStartTime(for: taskIdentifier) {
                    return endTime.timeIntervalSince(startTime)
                }
                return nil
            }()
            
            let event = await BackgroundTaskEvent(
                id: UUID(),
                taskIdentifier: taskIdentifier,
                type: .taskExecutionCompleted,
                timestamp: endTime,
                duration: duration,
                success: success,
                errorMessage: success ? nil : "Task completed with failure",
                metadata: [
                    "completion_success": String(success),
                    "task_type": taskType
                ],
                systemInfo: SystemInfo(
                    backgroundAppRefreshStatus: await UIApplication.shared.backgroundRefreshStatus,
                    deviceModel: UIDevice.current.model,
                    systemVersion: UIDevice.current.systemVersion,
                    lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                    batteryLevel: UIDevice.current.batteryLevel,
                    batteryState: UIDevice.current.batteryState
                )
            )
            BackgroundTaskDataStore.shared.recordEvent(event)
            
            // Clean up start time
            await BGTaskSwizzler.taskStartTimesManager.removeStartTime(for: taskIdentifier)
        }
        
        // Call original method - after swizzling, bt_setTaskCompleted selector points to original implementation
        let method = class_getInstanceMethod(BGTask.self, #selector(BGTask.bt_setTaskCompleted(success:)))!
        let originalImp = method_getImplementation(method)
        typealias SetTaskCompletedFunction = @convention(c) (BGTask, Selector, Bool) -> Void
        let originalSetTaskCompleted = unsafeBitCast(originalImp, to: SetTaskCompletedFunction.self)
        originalSetTaskCompleted(self, #selector(BGTask.bt_setTaskCompleted(success:)), success)
    }
}
