//
//  EventTypeTests.swift
//  BackgroundTimeTests
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Testing
import Foundation
import UIKit
import BackgroundTasks
@testable import BackgroundTime

@Suite("Event Type Tests")
struct EventTypeTests {
    
    @Test("All Event Types Have Icons")
    func testEventTypeIcons() async throws {
        for eventType in BackgroundTaskEventType.allCases {
            let icon = eventType.icon
            #expect(!icon.isEmpty, "Event type \(eventType.rawValue) should have an icon")
        }
    }
    
    @Test("Event Type Raw Values")
    func testEventTypeRawValues() async throws {
        #expect(BackgroundTaskEventType.taskScheduled.rawValue == "task_scheduled")
        #expect(BackgroundTaskEventType.taskExecutionStarted.rawValue == "task_execution_started")
        #expect(BackgroundTaskEventType.taskExecutionCompleted.rawValue == "task_execution_completed")
        #expect(BackgroundTaskEventType.taskExpired.rawValue == "task_expired")
        #expect(BackgroundTaskEventType.taskCancelled.rawValue == "task_cancelled")
        #expect(BackgroundTaskEventType.taskFailed.rawValue == "task_failed")
    }
    
    @Test("Event Type CaseIterable completeness")
    func testEventTypeCaseIterable() async throws {
        let allCases = BackgroundTaskEventType.allCases
        
        // Verify we have all expected basic event types
        let expectedTypes: [BackgroundTaskEventType] = [
            .taskScheduled,
            .taskExecutionStarted,
            .taskExecutionCompleted,
            .taskExpired,
            .taskCancelled,
            .taskFailed,
            .metricKitDataReceived,
            .appEnteredBackground,
            .appWillEnterForeground
        ]
        
        for expectedType in expectedTypes {
            #expect(allCases.contains(expectedType), "Should contain event type: \(expectedType.rawValue)")
        }
        
        // Verify we have at least the basic types
        #expect(allCases.count >= expectedTypes.count, "Should have at least \(expectedTypes.count) event types")
        
        // Test iOS 26.0+ continuous task events if available
        if #available(iOS 26.0, *) {
            let continuousTypes: [BackgroundTaskEventType] = [
                .continuousTaskStarted,
                .continuousTaskPaused,
                .continuousTaskResumed,
                .continuousTaskStopped,
                .continuousTaskProgress
            ]
            
            for continuousType in continuousTypes {
                #expect(allCases.contains(continuousType), "Should contain continuous task type: \(continuousType.rawValue)")
            }
        }
    }
    
    @Test("Event Type isContinuousTaskEvent validation")
    func testEventTypeContinuousTaskValidation() async throws {
        // Test regular event types are not continuous
        let regularTypes: [BackgroundTaskEventType] = [
            .taskScheduled,
            .taskExecutionStarted,
            .taskExecutionCompleted,
            .taskExpired,
            .taskCancelled,
            .taskFailed,
            .metricKitDataReceived,
            .appEnteredBackground,
            .appWillEnterForeground
        ]
        
        for eventType in regularTypes {
            #expect(eventType.isContinuousTaskEvent == false, "\(eventType.rawValue) should not be identified as continuous task event")
        }
        
        // Test iOS 26.0+ continuous task event types if available
        if #available(iOS 26.0, *) {
            let continuousTypes: [BackgroundTaskEventType] = [
                .continuousTaskStarted,
                .continuousTaskPaused,
                .continuousTaskResumed,
                .continuousTaskStopped,
                .continuousTaskProgress
            ]
            
            for eventType in continuousTypes {
                #expect(eventType.isContinuousTaskEvent == true, "\(eventType.rawValue) should be identified as continuous task event")
            }
        }
    }
    
    @Test("Event Type string representation consistency")
    func testEventTypeStringRepresentation() async throws {
        // Test that raw values follow consistent naming pattern
        let allCases = BackgroundTaskEventType.allCases
        
        for eventType in allCases {
            let rawValue = eventType.rawValue
            
            // Should not be empty
            #expect(!rawValue.isEmpty, "Raw value should not be empty for \(eventType)")
            
            // Should be lowercase with underscores (snake_case)
            #expect(rawValue == rawValue.lowercased(), "Raw value should be lowercase for \(eventType)")
            
            // Should not start or end with underscore
            #expect(!rawValue.hasPrefix("_"), "Raw value should not start with underscore for \(eventType)")
            #expect(!rawValue.hasSuffix("_"), "Raw value should not end with underscore for \(eventType)")
            
            // Should contain only letters, numbers, and underscores
            let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_")
            let rawValueCharacterSet = CharacterSet(charactersIn: rawValue)
            #expect(allowedCharacterSet.isSuperset(of: rawValueCharacterSet), "Raw value should only contain allowed characters for \(eventType)")
        }
    }
}
