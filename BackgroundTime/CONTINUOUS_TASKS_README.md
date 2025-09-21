# Continuous Background Tasks Support (iOS 26.0+)

The BackgroundTime dashboard now includes conditional support for Continuous Background Tasks, available in iOS 26.0 and later.

## Overview

Continuous Background Tasks allow your app to perform long-running tasks in the background without the typical 30-second limitation of standard background tasks. This feature is ideal for:

- Data synchronization
- Location tracking
- Media processing
- Network downloads
- Real-time data processing

## Features Added

### New Event Types
- `continuousTaskStarted` - When a continuous task begins
- `continuousTaskPaused` - When a task is temporarily suspended
- `continuousTaskResumed` - When a paused task resumes
- `continuousTaskStopped` - When a task completes or is terminated
- `continuousTaskProgress` - Progress updates during task execution

### New Dashboard Tab
The dashboard automatically shows a "Continuous" tab on iOS 26+ devices, providing:
- Active task monitoring
- Task lifecycle visualization
- Performance metrics
- Progress tracking
- Timeline view of continuous task events

### New Data Models
- `ContinuousTaskInfo` - Comprehensive task information
- `ContinuousTaskStatus` - Task state management
- `ContinuousTaskProgress` - Progress tracking
- `TaskPriority` - Task priority levels

## Setup Requirements

### 1. Info.plist Configuration
Add your continuous background task identifiers to your app's Info.plist:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.yourapp.data-sync</string>
    <string>com.yourapp.location-tracking</string>
</array>
```

### 2. Entitlements
Ensure your app has the necessary background modes entitlement:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>background-task</string>
    <string>background-processing</string>
</array>
```

## Usage Example

### Basic Implementation

```swift
import BackgroundTasks

@available(iOS 26.0, *)
class MyContinuousTaskManager {
    private let backgroundTime = BackgroundTime.shared
    
    func startDataSync() async throws {
        let task = try await BGContinuousTask.request("com.yourapp.data-sync") {
            // Handle expiration
            await self.logTaskStopped(reason: "expired")
        }
        
        // Log task start
        await backgroundTime.recordEvent(BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "com.yourapp.data-sync",
            type: .continuousTaskStarted,
            timestamp: Date(),
            success: true,
            systemInfo: currentSystemInfo()
        ))
        
        // Your long-running work here...
        await performDataSync(task: task)
    }
    
    func updateProgress(completed: Int64, total: Int64) async {
        await backgroundTime.recordEvent(BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: "com.yourapp.data-sync", 
            type: .continuousTaskProgress,
            timestamp: Date(),
            success: true,
            metadata: [
                "completed_units": "\(completed)",
                "total_units": "\(total)"
            ],
            systemInfo: currentSystemInfo()
        ))
    }
}
```

### SwiftUI Integration

```swift
struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                // Your app content
                
                NavigationLink("Background Tasks Dashboard") {
                    BackgroundTimeDashboard()
                }
            }
        }
    }
}
```

## Dashboard Features

### Overview Tab Enhancements
- Shows continuous task statistics alongside regular background tasks
- Displays active task count and total events
- Visual indicators for continuous vs. regular tasks

### Continuous Tasks Tab (iOS 26+ only)
- **Active Tasks Summary**: Real-time view of running continuous tasks
- **Task List**: Detailed view of each continuous task with status indicators
- **Timeline Chart**: Visual representation of task lifecycle events
- **Performance Metrics**: Runtime statistics and efficiency data

### Timeline Integration
- Continuous task events appear in the main timeline
- Special icons and colors for continuous task events
- Progress tracking visualization

## Conditional Compilation

The framework automatically handles version compatibility:

```swift
// The dashboard automatically adapts based on iOS version
if #available(iOS 26.0, *) {
    // Continuous tasks tab is available
    // Enhanced features are enabled
} else {
    // Standard dashboard without continuous tasks features
}
```

## Best Practices

### 1. Task Lifecycle Management
```swift
@available(iOS 26.0, *)
class TaskLifecycleManager {
    func manageLongRunningTask() async {
        do {
            // Start the task
            let task = try await startContinuousTask()
            
            // Monitor for system events that might require pausing
            if ProcessInfo.processInfo.isLowPowerModeEnabled {
                await pauseTask()
                // Wait for better conditions
                await resumeTask()
            }
            
            // Complete the task gracefully
            await stopTask(success: true)
        } catch {
            await logTaskFailure(error)
        }
    }
}
```

### 2. Progress Reporting
```swift
func reportProgress(_ progress: Progress) async {
    await backgroundTime.recordEvent(BackgroundTaskEvent(
        id: UUID(),
        taskIdentifier: taskIdentifier,
        type: .continuousTaskProgress,
        timestamp: Date(),
        success: true,
        metadata: [
            "completed_units": "\(progress.completedUnitCount)",
            "total_units": "\(progress.totalUnitCount)",
            "fraction_completed": "\(progress.fractionCompleted)",
            "localized_description": progress.localizedDescription ?? ""
        ],
        systemInfo: currentSystemInfo()
    ))
}
```

### 3. Resource Management
```swift
@available(iOS 26.0, *)
class ResourceAwareTaskManager {
    func shouldPauseTask() -> Bool {
        return ProcessInfo.processInfo.isLowPowerModeEnabled ||
               ProcessInfo.processInfo.thermalState != .nominal
    }
    
    func adjustTaskBehavior() async {
        if shouldPauseTask() {
            await pauseTask()
            // Monitor for better conditions
            await waitForBetterConditions()
            await resumeTask()
        }
    }
}
```

## Monitoring and Debugging

### Dashboard Analytics
The continuous tasks dashboard provides:
- Real-time task status monitoring
- Performance metrics and trends
- Error tracking and diagnostics
- Resource usage patterns

### Debug Information
Enable debug logging to see detailed continuous task information:

```swift
BackgroundTime.shared.configure(
    apiKey: "your-api-key",
    enableDebugLogging: true
)
```

### Key Metrics Tracked
- Task start/stop frequency
- Average runtime per task
- Pause/resume patterns  
- Failure rates and error types
- System resource impact

## Migration Guide

### From Standard Background Tasks
If you're currently using standard background tasks (`BGTaskRequest`), you can migrate to continuous tasks where appropriate:

```swift
// Before (Standard Background Task)
func scheduleBackgroundTask() {
    let request = BGAppRefreshTaskRequest(identifier: "com.app.refresh")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    try? BGTaskScheduler.shared.submit(request)
}

// After (Continuous Background Task - iOS 26+)
@available(iOS 26.0, *)
func startContinuousTask() async throws {
    let task = try await BGContinuousTask.request("com.app.continuous-sync") {
        // Handle expiration
    }
    // Long-running work can now continue indefinitely
}
```

### Compatibility Layer
The framework maintains backward compatibility:
- iOS 25 and earlier: Standard dashboard without continuous tasks features
- iOS 26+: Full continuous tasks support with enhanced dashboard

## Limitations and Considerations

### System Limitations
- Continuous tasks are subject to system resource management
- Tasks may be suspended during low power mode
- Thermal management can affect task execution
- User can disable background processing in Settings

### Best Practices for Resource Usage
- Monitor system thermal state
- Respect low power mode
- Implement graceful pause/resume logic
- Use appropriate task priorities
- Clean up resources properly

### Testing
- Test on physical devices (not just simulator)
- Test under various system conditions (low power, thermal states)
- Verify task behavior during app backgrounding/foregrounding
- Monitor resource usage and battery impact

## Troubleshooting

### Common Issues

1. **Task not starting**
   - Verify Info.plist configuration
   - Check background modes entitlement
   - Ensure iOS 26+ device

2. **Task getting suspended**
   - Monitor system thermal state
   - Check for low power mode
   - Implement proper pause/resume logic

3. **Dashboard not showing continuous tasks**
   - Verify iOS version compatibility
   - Check that continuous task events are being logged
   - Ensure BackgroundTime SDK is properly initialized

### Debug Steps
1. Enable debug logging
2. Check dashboard timeline for continuous task events
3. Monitor system console for background task messages
4. Verify task identifiers match Info.plist entries
5. Test on physical device with various system states

## API Reference

See `ContinuousBackgroundTaskExample.swift` for complete implementation examples and `BackgroundTimeModels.swift` for detailed API documentation.