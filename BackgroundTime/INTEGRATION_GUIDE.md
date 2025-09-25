# BackgroundTime SDK Integration Guide

## Overview

BackgroundTime is a comprehensive iOS SDK for monitoring and analyzing background task performance. It features thread-safe architecture with circular buffer storage, automatic instrumentation via method swizzling, and real-time analytics.

## Architecture Features

### Core Architecture
- **Singleton Pattern**: Thread-safe singleton implementation with proper initialization locks
- **Method Swizzling**: Automatic instrumentation of BGTaskScheduler and BGTask lifecycle events
- **Circular Buffer Storage**: Memory-efficient metric storage with configurable capacity limits
- **Reader-Writer Locks**: Concurrent metric access and updates using dispatch queues
- **Package Manager Support**: Swift Package Manager, CocoaPods, and manual framework integration

## Integration Options

### 1. Swift Package Manager (Recommended)

Add BackgroundTime to your project using SPM:

1. In Xcode, go to **File > Add Package Dependencies**
2. Enter the repository URL: `https://github.com/yourusername/BackgroundTime`
3. Choose the version and add to your target

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/BackgroundTime", from: "1.0.0")
]
```

### 2. CocoaPods

Add to your `Podfile`:

```ruby
pod 'BackgroundTime', '~> 1.0'
```

Then run:
```bash
pod install
```

### 3. Manual Integration

1. Download the BackgroundTime framework
2. Drag and drop into your Xcode project
3. Add to **Embedded Binaries** and **Linked Frameworks**
4. Import the module: `import BackgroundTime`

## Usage

### Basic Setup

```swift
import BackgroundTime

// In your AppDelegate or App struct
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    // Initialize BackgroundTime with default configuration
    BackgroundTime.shared.initialize()
    
    // Or with custom configuration
    let config = BackgroundTimeConfiguration(
        maxStoredEvents: 5000,
        apiEndpoint: URL(string: "https://your-dashboard.com"),
        enableNetworkSync: true,
        enableDetailedLogging: true
    )
    BackgroundTime.shared.initialize(configuration: config)
    
    return true
}
```

### Background Task Registration

Use the enhanced registration method for automatic instrumentation:

```swift
import BackgroundTasks

func setupBackgroundTasks() {
    // Use BackgroundTime's instrumented registration
    BGTaskScheduler.shared.registerBackgroundTime(
        forTaskWithIdentifier: "com.yourapp.refresh",
        using: nil
    ) { task in
        handleAppRefreshTask(task as! BGAppRefreshTask)
    }
    
    BGTaskScheduler.shared.registerBackgroundTime(
        forTaskWithIdentifier: "com.yourapp.processing",
        using: nil
    ) { task in
        handleProcessingTask(task as! BGProcessingTask)
    }
}
```

### Manual Task Tracking (Optional)

If you prefer manual tracking:

```swift
func handleAppRefreshTask(_ task: BGAppRefreshTask) {
    // BackgroundTime automatically tracks task lifecycle
    
    task.expirationHandler = {
        // Expiration is automatically tracked
        task.setTaskCompleted(success: false)
    }
    
    Task {
        let success = await performDataRefresh()
        // Completion is automatically tracked
        task.setTaskCompleted(success: success)
    }
}
```

### Analytics and Monitoring

```swift
// Get current statistics
let stats = BackgroundTime.shared.getCurrentStats()
print("Success rate: \(stats.successRate)")
print("Average execution time: \(stats.averageExecutionTime)")

// Get all recorded events
let events = BackgroundTime.shared.getAllEvents()

// Export data for dashboard
let dashboardData = BackgroundTime.shared.exportDataForDashboard()

// Sync with remote dashboard (if configured)
Task {
    do {
        try await BackgroundTime.shared.syncWithDashboard()
    } catch {
        print("Dashboard sync failed: \(error)")
    }
}
```

### Performance Monitoring

```swift
// Get data store performance metrics
let dataStore = BackgroundTaskDataStore.shared
let performanceReport = dataStore.getDataStorePerformance()
let bufferStats = dataStore.getBufferStatistics()

print("Buffer utilization: \(bufferStats.utilizationPercentage)%")
print("Average operation time: \(performanceReport.averageDuration)ms")
```

## Configuration Options

### BackgroundTimeConfiguration

```swift
let config = BackgroundTimeConfiguration(
    maxStoredEvents: 5000,           // Circular buffer capacity
    apiEndpoint: URL(string: "..."), // Optional dashboard endpoint
    enableNetworkSync: true,         // Enable automatic dashboard sync
    enableDetailedLogging: true      // Enable detailed logging
)
```

### Thread Safety Features

The SDK uses several thread-safety mechanisms:

- **Reader-Writer Locks**: Implemented using concurrent dispatch queues with barriers
- **Circular Buffer**: Thread-safe circular buffer with atomic operations
- **Singleton Protection**: Initialization locks prevent race conditions
- **Performance Monitoring**: Tracks operation performance and access patterns

### Memory Management

- **Circular Buffer**: Automatically manages memory by dropping oldest events when capacity is reached
- **Configurable Capacity**: Adjust storage capacity based on your needs
- **Efficient Storage**: Uses memory-efficient data structures optimized for frequent access

## Advanced Features

### Custom Event Recording

```swift
// The SDK automatically records events, but you can access the underlying store
let customEvent = BackgroundTaskEvent(
    id: UUID(),
    taskIdentifier: "custom-task",
    type: .taskExecutionStarted,
    timestamp: Date(),
    success: true,
    systemInfo: SystemInfo.current()
)

// Note: Direct event recording is typically not needed
// The SDK handles this automatically through method swizzling
```

### Dashboard Integration

```swift
// Export comprehensive dashboard data
let dashboardData = BackgroundTime.shared.exportDataForDashboard()

// The data includes:
// - Current statistics
// - All recorded events
// - Timeline data
// - System information
```

### Error Handling

```swift
do {
    try await BackgroundTime.shared.syncWithDashboard()
} catch NetworkError.noEndpointConfigured {
    print("No dashboard endpoint configured")
} catch NetworkError.serverError(let statusCode) {
    print("Server error: \(statusCode)")
} catch {
    print("Sync error: \(error)")
}
```

## Best Practices

1. **Initialize Early**: Call `initialize()` in your app delegate's `didFinishLaunching`
2. **Use Enhanced Registration**: Use `registerBackgroundTime` for automatic instrumentation
3. **Monitor Performance**: Regularly check buffer utilization and performance metrics
4. **Configure Capacity**: Set `maxStoredEvents` based on your app's needs and memory constraints
5. **Enable Dashboard Sync**: Use network sync for remote monitoring and analytics

## Troubleshooting

### Common Issues

1. **High Memory Usage**: Reduce `maxStoredEvents` in configuration
2. **Missing Events**: Ensure you're using `registerBackgroundTime` for task registration
3. **Dashboard Sync Fails**: Check network configuration and endpoint URL
4. **Performance Issues**: Monitor buffer statistics and consider increasing capacity

### Debug Logging

Enable detailed logging in your configuration:

```swift
let config = BackgroundTimeConfiguration(
    enableDetailedLogging: true
)
```

This will provide comprehensive logs about:
- Task lifecycle events
- Buffer operations
- Network requests
- Performance metrics

## Requirements

- iOS 14.0+
- macOS 11.0+
- tvOS 14.0+
- watchOS 7.0+
- visionOS 1.0+
- Swift 5.7+
- Xcode 14.0+

## Support

For issues, questions, or contributions, please visit the project repository or contact the development team.