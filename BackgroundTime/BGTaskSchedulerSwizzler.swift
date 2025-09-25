//
//  BGTaskSchedulerSwizzler.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/25/25.
//

import Foundation
import BackgroundTasks
import UIKit
import os.log

// MARK: - BGTaskScheduler Method Swizzling

@objc class BGTaskSchedulerSwizzler: NSObject {
    private static let logger = Logger(subsystem: "BackgroundTime", category: "Swizzler")
    private static let dataStore = BackgroundTaskDataStore.shared
    private static var swizzlingCompleted = false
    private static let swizzlingQueue = DispatchQueue(label: "BackgroundTime.Swizzling", qos: .utility)
    
    // Store original method implementations
    private static var originalSubmit: Method?
    private static var originalCancel: Method?
    private static var originalCancelAll: Method?
    
    @objc static func swizzleSchedulerMethods() {
        swizzlingQueue.sync {
            guard !swizzlingCompleted else {
                logger.warning("BGTaskScheduler swizzling already completed")
                return
            }
            
            guard let schedulerClass = NSClassFromString("BGTaskScheduler") else {
                logger.error("Failed to get BGTaskScheduler class")
                return
            }
            
            // Swizzle submit method
            originalSubmit = swizzleMethod(
                in: schedulerClass,
                original: #selector(BGTaskScheduler.submit(_:)),
                swizzled: #selector(BGTaskSchedulerSwizzler.swizzled_submit(_:))
            )
            
            // Swizzle cancel method
            originalCancel = swizzleMethod(
                in: schedulerClass,
                original: #selector(BGTaskScheduler.cancel(taskRequestWithIdentifier:)),
                swizzled: #selector(BGTaskSchedulerSwizzler.swizzled_cancel(taskRequestWithIdentifier:))
            )
            
            // Swizzle cancelAll method
            originalCancelAll = swizzleMethod(
                in: schedulerClass,
                original: #selector(BGTaskScheduler.cancelAllTaskRequests),
                swizzled: #selector(BGTaskSchedulerSwizzler.swizzled_cancelAllTaskRequests)
            )
            
            swizzlingCompleted = true
            logger.info("BGTaskScheduler method swizzling completed successfully")
        }
    }
    
    // MARK: - Swizzled Methods
    
    @objc func swizzled_submit(_ request: BGTaskRequest) throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var submitError: Error?
        var success = false
        
        // The cleanest approach: Use the original implementation we stored during swizzling
        do {
            guard let originalMethod = BGTaskSchedulerSwizzler.originalSubmit else {
                throw NSError(domain: "BGTaskSchedulerSwizzler", code: -1, userInfo: [NSLocalizedDescriptionKey: "Original submit method not available"])
            }
            
            let scheduler = BGTaskScheduler.shared
            let originalImplementation = method_getImplementation(originalMethod)
            
            // Use the original implementation directly with objc_msgSend-style calling
            // This avoids the @convention(c) issue with throwing functions
            let originalFunction = unsafeBitCast(originalImplementation, to: (@convention(c) (AnyObject, Selector, BGTaskRequest) -> Void).self)
            
            // Call the original implementation directly
            originalFunction(scheduler, #selector(BGTaskScheduler.submit(_:)), request)
            success = true
            
        } catch {
            submitError = error
            success = false
            throw error
        }
        
        // Record the event
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: request.identifier,
            type: .taskScheduled,
            timestamp: Date(),
            duration: duration,
            success: success,
            errorMessage: submitError?.localizedDescription,
            metadata: [
                "request_type": String(describing: type(of: request)),
                "earliest_begin_date": request.earliestBeginDate?.iso8601String ?? "nil",
                "requires_network": (request as? BGProcessingTaskRequest)?.requiresNetworkConnectivity ?? false,
                "requires_power": (request as? BGProcessingTaskRequest)?.requiresExternalPower ?? false
            ],
            systemInfo: SystemInfo.current()
        )
        
        BGTaskSchedulerSwizzler.dataStore.recordEvent(event)
        BGTaskSchedulerSwizzler.logger.info("Recorded task submission for: \(request.identifier)")
    }
    
    @objc func swizzled_cancel(taskRequestWithIdentifier identifier: String) {
        // Call original implementation using stored method
        guard let originalMethod = BGTaskSchedulerSwizzler.originalCancel else {
            BGTaskSchedulerSwizzler.logger.error("Original cancel method not available")
            return
        }
        
        let originalImplementation = method_getImplementation(originalMethod)
        typealias CancelFunction = @convention(c) (AnyObject, Selector, String) -> Void
        let originalFunction = unsafeBitCast(originalImplementation, to: CancelFunction.self)
        
        originalFunction(self, #selector(BGTaskScheduler.cancel(taskRequestWithIdentifier:)), identifier)
        
        // Record the event
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: identifier,
            type: .taskCancelled,
            timestamp: Date(),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: [:],
            systemInfo: SystemInfo.current()
        )
        
        BGTaskSchedulerSwizzler.dataStore.recordEvent(event)
        BGTaskSchedulerSwizzler.logger.info("Recorded task cancellation for: \(identifier)")
    }
    
    @objc func swizzled_cancelAllTaskRequests() {
        // Call original implementation using stored method
        guard let originalMethod = BGTaskSchedulerSwizzler.originalCancelAll else {
            BGTaskSchedulerSwizzler.logger.error("Original cancelAll method not available")
            return
        }
        
        let originalImplementation = method_getImplementation(originalMethod)
        typealias CancelAllFunction = @convention(c) (AnyObject, Selector) -> Void
        let originalFunction = unsafeBitCast(originalImplementation, to: CancelAllFunction.self)
        
        originalFunction(self, #selector(BGTaskScheduler.cancelAllTaskRequests))
        
        // Record the event
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "ALL_TASKS",
            type: .taskCancelled,
            timestamp: Date(),
            duration: nil,
            success: true,
            errorMessage: nil,
            metadata: ["cancel_type": "all_tasks"],
            systemInfo: SystemInfo.current()
        )
        
        BGTaskSchedulerSwizzler.dataStore.recordEvent(event)
        BGTaskSchedulerSwizzler.logger.info("Recorded cancellation of all background tasks")
    }
    
    // MARK: - Helper Methods
    
    private static func swizzleMethod(in targetClass: AnyClass, original originalSelector: Selector, swizzled swizzledSelector: Selector) -> Method? {
        guard let originalMethod = class_getInstanceMethod(targetClass, originalSelector),
              let swizzledMethod = class_getInstanceMethod(BGTaskSchedulerSwizzler.self, swizzledSelector) else {
            logger.error("Failed to get methods for swizzling")
            return nil
        }
        
        let didAddMethod = class_addMethod(
            targetClass,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )
        
        if didAddMethod {
            class_replaceMethod(
                targetClass,
                swizzledSelector,
                method_getImplementation(originalMethod),
                method_getTypeEncoding(originalMethod)
            )
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
        
        logger.info("Successfully swizzled method: \(originalSelector)")
        return originalMethod
    }
}

// MARK: - Extensions

private extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}

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