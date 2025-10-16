# BackgroundTime SDK

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2015%2B%20%7C%20macOS%2012%2B-lightgrey)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Beta](https://img.shields.io/badge/Status-Beta-yellow.svg)](https://github.com/yourusername/BackgroundTime/releases)

A comprehensive iOS framework for monitoring and analyzing BackgroundTasks performance using method swizzling to provide deep insights into your app's background processing behavior.

> **⚠️ Beta Release**: This is a beta version. APIs may change before the stable release. Feedback and contributions are welcome!

## Overview

BackgroundTime SDK automatically tracks all BackgroundTasks API usage in your iOS app without requiring code changes. It uses method swizzling to intercept BGTaskScheduler calls and provides detailed analytics through a beautiful SwiftUI dashboard.

## Features

### 🔍 **Automatic Tracking**
- **Zero-code integration** - Just initialize the SDK and it automatically tracks all background tasks
- **Method swizzling** - Intercepts all BGTaskScheduler and BGTask method calls
- **Comprehensive coverage** - Tracks scheduling, execution, completion, cancellation, and failures

### 📊 **Rich Analytics Dashboard**
- **Overview Tab** - Key statistics, success rates, execution patterns
- **Timeline Tab** - Chronological view of all background task events
- **Performance Tab** - Execution duration trends and task-specific metrics
- **Errors Tab** - Detailed error analysis and failure patterns

### 📈 **Detailed Metrics**
- **Execution Statistics** - Total scheduled/executed/completed/failed tasks
- **Performance Metrics** - Average duration, success rates, hourly patterns
- **System Context** - Battery level, low power mode, background app refresh status
- **Error Tracking** - Failure reasons, retry attempts, system constraint impacts

### 🌐 **Remote Dashboard Support**
- **Data Export** - JSON export for integration with web dashboards
- **Network Sync** - Optional remote dashboard synchronization
- **Real-time Monitoring** - Live updates for production app monitoring

## Quick Start

### 1. Add the Package

#### Swift Package Manager
```swift
dependencies: [
    .package(url: "https://github.com/yourusername/BackgroundTime", from: "0.1.0-beta")
]
```

#### Xcode
1. File → Add Package Dependencies
2. Enter: `https://github.com/yourusername/BackgroundTime`
3. Select "Up to Next Major Version" with `0.1.0-beta`
4. Add to your target

### 2. Initialize the SDK

In your App.swift file:

```swift
import BackgroundTime

@main
struct MyApp: App {
    init() {
        // Initialize BackgroundTime SDK - that's it!
        BackgroundTime.shared.initialize()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 3. Add the Dashboard (Optional)

```swift
import BackgroundTime

struct ContentView: View {
    @State private var showDashboard = false
    
    var body: some View {
        NavigationView {
            YourAppContent()
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Dashboard") {
                            showDashboard = true
                        }
                    }
                }
        }
        .sheet(isPresented: $showDashboard) {
            if #available(iOS 16.0, *) {
                BackgroundTimeDashboard()
            }
        }
    }
}
```

## Advanced Configuration

### Custom Configuration

```swift
let config = BackgroundTimeConfiguration(
    maxStoredEvents: 2000,           // Maximum events to store locally
    apiEndpoint: URL(string: "https://your-dashboard.com/api"),
    enableNetworkSync: true,         // Enable remote dashboard sync
    enableDetailedLogging: true      // Enable detailed logging
)

BackgroundTime.shared.initialize(configuration: config)
```

### Accessing Data Programmatically

```swift
// Get current statistics
let stats = BackgroundTime.shared.getCurrentStats()
print("Success rate: \(stats.successRate * 100)%")

// Get all events
let events = BackgroundTime.shared.getAllEvents()
print("Total events: \(events.count)")

// Export for external dashboard
let dashboardData = BackgroundTime.shared.exportDataForDashboard()
```

## Dashboard Metrics Explained

### Overview Tab
- **Total Executed**: Number of background tasks that started execution
- **Success Rate**: Percentage of tasks that completed successfully
- **Failed Tasks**: Number of tasks that failed or were cancelled
- **Average Duration**: Mean execution time for completed tasks
- **Executions by Hour**: 24-hour pattern showing when tasks typically run

### Performance Tab
- **Duration Trends**: Line chart showing execution times over time
- **Task-Specific Metrics**: Individual performance data for each task identifier
- **Efficiency Metrics**: Time between scheduling and execution

### Error Analysis
- **Error Types**: Categorized breakdown of failure reasons
- **System Constraints**: Impact of low power mode, background refresh settings
- **Failure Patterns**: When and why tasks are most likely to fail

## Example App Integration

The package includes a complete example app demonstrating integration in a social media/chat app context:

### Background Tasks Examples:
- **Feed Refresh** (`BGAppRefreshTask`) - Updates social media feed
- **Media Download** (`BGProcessingTask`) - Downloads images/videos  
- **Chat Sync** (`BGAppRefreshTask`) - Synchronizes chat messages

### Key Implementation Points:
```swift
// Register background tasks
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "refresh-social-feed",
    using: nil
) { task in
    await handleFeedRefresh(task as! BGAppRefreshTask)
}

// Schedule tasks
let request = BGAppRefreshTaskRequest(identifier: "refresh-social-feed")
request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
try BGTaskScheduler.shared.submit(request)
```

The SDK automatically tracks all of these operations without any additional code!

## Dashboard Visualizations

### 📊 Statistics Cards
Quick overview cards showing:
- Total executions with trend indicators
- Success rate with color-coded status
- Failure count with error categorization
- Average duration with performance indicators

### 📈 Charts and Graphs
- **Hourly Pattern Chart**: Shows when your background tasks typically execute
- **Duration Trends**: Line chart showing performance over time
- **Error Distribution**: Bar chart breaking down failure types
- **Timeline View**: Chronological event stream with filtering

### 🔍 Detailed Analysis
- **Per-Task Metrics**: Individual performance breakdown for each task identifier
- **System Context**: How device state affects background task performance
- **Error Details**: Specific failure reasons with suggested improvements

## Use Cases

### For Managers
- **Performance Monitoring**: Track background task reliability in production
- **Resource Planning**: Understand when and how often tasks run
- **Quality Metrics**: Monitor success rates and failure patterns
- **User Impact Assessment**: Correlate task performance with user experience

### For Engineers
- **Debugging**: Identify why background tasks are failing
- **Optimization**: Find performance bottlenecks and improve efficiency
- **Testing**: Validate background task behavior across different scenarios
- **Monitoring**: Real-time visibility into production background task performance

## Architecture

### Method Swizzling
The SDK uses runtime method swizzling to intercept:
- `BGTaskScheduler.submit(_:)` - Task scheduling
- `BGTaskScheduler.cancel(taskRequestWithIdentifier:)` - Task cancellation
- `BGTask.setTaskCompleted(success:)` - Task completion
- Expiration handlers - Task timeouts

### Data Storage
- **Local Storage**: Events stored in UserDefaults with configurable limits
- **Memory Management**: Automatic cleanup of old events
- **Thread Safety**: Concurrent queues for safe data access
- **Persistence**: Data survives app termination and restart

### Network Integration
- **Optional Remote Sync**: Upload data to your dashboard backend
- **JSON Export**: Standard format for integration with existing tools
- **Configurable Endpoints**: Support for custom dashboard URLs
- **Error Handling**: Robust network error handling and retry logic

## Beta Feedback

We'd love your feedback on this beta release! Please:

- 🐛 [Report bugs](https://github.com/yourusername/BackgroundTime/issues/new?labels=bug)  
- 💡 [Suggest features](https://github.com/yourusername/BackgroundTime/issues/new?labels=enhancement)
- 📖 [Improve documentation](https://github.com/yourusername/BackgroundTime/issues/new?labels=documentation)
- ⭐ Star the repo if you find it useful!

## Requirements

- iOS 14.0+
- Xcode 12.0+
- Swift 5.3+

## Dashboard Requirements

The SwiftUI dashboard requires:
- iOS 16.0+ (for Charts framework)
- Falls back gracefully on older versions

## License

MIT License - see LICENSE file for details

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## Support

For questions, issues, or feature requests:
- Open an issue on GitHub
- Check the documentation
- Review the example app for integration patterns

---

**BackgroundTime SDK** - Making background task monitoring effortless and insightful. 🚀