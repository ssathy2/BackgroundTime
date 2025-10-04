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
        // Swizzle each concrete BGTask subclass
        swizzleBGAppRefreshTask()
        swizzleBGProcessingTask()
        if #available(iOS 26.0, *) {
            swizzleBGContinuedProcessingTask()
        } else {
            // Fallback on earlier versions
        }
    }
    
    // MARK: - BGAppRefreshTask Swizzling
    
    private static func swizzleBGAppRefreshTask() {
        swizzleSetTaskCompletedMethod(for: BGAppRefreshTask.self, className: "BGAppRefreshTask")
    }
    
    // MARK: - BGProcessingTask Swizzling
    
    private static func swizzleBGProcessingTask() {
        swizzleSetTaskCompletedMethod(for: BGProcessingTask.self, className: "BGProcessingTask")
    }
    
    // MARK: - BGContinuedProcessingTask Swizzling
    
    @available(iOS 26.0, *)
    private static func swizzleBGContinuedProcessingTask() {
        swizzleSetTaskCompletedMethod(for: BGContinuedProcessingTask.self, className: "BGContinuedProcessingTask")
    }
    
    // MARK: - Generic Swizzling Method
    
    private static func swizzleSetTaskCompletedMethod<T: BGTask>(for taskClass: T.Type, className: String) {
        let originalSelector = #selector(BGTask.setTaskCompleted(success:))
        let swizzledSelector = #selector(BGTask.bt_setTaskCompleted(success:))
        
        guard let originalMethod = class_getInstanceMethod(taskClass, originalSelector) else {
            logger.error("❌ Failed to get original setTaskCompleted method for \(className)")
            return
        }
        
        guard let swizzledMethod = class_getInstanceMethod(BGTask.self, swizzledSelector) else {
            logger.error("❌ Failed to get swizzled bt_setTaskCompleted method")
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    static func resetTaskStartTimesManager() {
        taskStartTimesManager = .init()
    }
    
    nonisolated static func swizzleTaskCompletion(for task: BGTask, startTime: Date) {
        let taskIdentifier = task.identifier
        Task { @Sendable in
            await taskStartTimesManager.setStartTime(startTime, for: taskIdentifier)
        }
        
        let logger = Logger(subsystem: "BackgroundTime", category: "TaskTracking")
        
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
                    metadata: [
                        "expiration_handler": "true",
                        "auto_tracked": "true",
                        "tracking_method": "swizzling"
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
                
                await MainActor.run {
                    MetricCollectionManager.shared.recordTaskExpiration(identifier: taskIdentifier)
                }
                
                await taskStartTimesManager.removeStartTime(for: taskIdentifier)
            }
            
            if let originalExpirationHandler = originalExpirationHandler {
                Task { @MainActor in
                    originalExpirationHandler()
                }
            }
        }
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
                    "task_type": taskType,
                    "auto_tracked": "true",
                    "tracking_method": "swizzling"
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
            
            await MainActor.run {
                MetricCollectionManager.shared.recordTaskExecutionEnd(
                    identifier: taskIdentifier, 
                    success: success, 
                    error: success ? nil : BackgroundTaskError.taskCancelled
                )
            }
            
            await BGTaskSwizzler.taskStartTimesManager.removeStartTime(for: taskIdentifier)
        }
        
        // Call original method (after swizzling, bt_setTaskCompleted points to the original implementation)
        self.bt_setTaskCompleted(success: success)
    }
}
