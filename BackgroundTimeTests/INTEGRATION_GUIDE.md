# BackgroundTime SDK Integration Guide

This guide provides step-by-step instructions for integrating BackgroundTime SDK into your iOS app for production background task monitoring.

## Integration Steps

### 1. Add BackgroundTime to Your Project

#### Using Swift Package Manager (Recommended)

In Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/yourusername/BackgroundTime`
3. Choose version and add to target

#### Using Package.swift
```swift
dependencies: [
    .package(url: "https://github.com/yourusername/BackgroundTime", from: "1.0.0")
],
targets: [
    .target(name: "YourApp", dependencies: ["BackgroundTime"])
]
```

### 2. Initialize in Your App

#### Basic Initialization
```swift
// App.swift
import SwiftUI
import BackgroundTime

@main
struct MyApp: App {
    init() {
        // Initialize BackgroundTime SDK
        BackgroundTime.shared.initialize()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

#### Advanced Configuration for Production
```swift
import BackgroundTime

@main
struct MyApp: App {
    init() {
        setupBackgroundTimeSDK()
    }
    
    private func setupBackgroundTimeSDK() {
        #if DEBUG
        // Development configuration
        let config = BackgroundTimeConfiguration(
            maxStoredEvents: 500,
            enableDetailedLogging: true
        )
        #else
        // Production configuration
        let config = BackgroundTimeConfiguration(
            maxStoredEvents: 2000,
            apiEndpoint: URL(string: "https://your-monitoring-dashboard.com/api"),
            enableNetworkSync: true,
            enableDetailedLogging: false
        )
        #endif
        
        BackgroundTime.shared.initialize(configuration: config)
    }
    
    // ... rest of your app
}
```

### 3. Add Dashboard Access (Optional)

#### In-App Dashboard
```swift
// ContentView.swift or your main view
import SwiftUI
import BackgroundTime

struct ContentView: View {
    @State private var showingBackgroundDashboard = false
    
    var body: some View {
        NavigationStack {
            YourMainContent()
                .toolbar {
                    #if DEBUG
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("BG Monitor") {
                            showingBackgroundDashboard = true
                        }
                    }
                    #endif
                }
        }
        .sheet(isPresented: $showingBackgroundDashboard) {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    BackgroundTimeDashboard()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingBackgroundDashboard = false
                                }
                            }
                        }
                }
            } else {
                Text("Dashboard requires iOS 16+")
                    .padding()
            }
        }
    }
}
```

#### Admin/Debug Menu Integration
```swift
struct DebugMenuView: View {
    @State private var showingStats = false
    @State private var statsText = ""
    
    var body: some View {
        List {
            Section("Background Tasks Monitoring") {
                Button("View Current Statistics") {
                    let stats = BackgroundTime.shared.getCurrentStats()
                    statsText = """
                    Background Task Statistics:
                    
                    📊 Execution Summary:
                    • Total Scheduled: \(stats.totalTasksScheduled)
                    • Total Executed: \(stats.totalTasksExecuted)
                    • Total Completed: \(stats.totalTasksCompleted)
                    • Total Failed: \(stats.totalTasksFailed)
                    • Total Expired: \(stats.totalTasksExpired)
                    
                    ⚡ Performance:
                    • Success Rate: \(String(format: "%.1f%%", stats.successRate * 100))
                    • Average Duration: \(String(format: "%.2fs", stats.averageExecutionTime))
                    
                    🕒 Last Execution: \(stats.lastExecutionTime?.formatted() ?? "Never")
                    📅 Generated: \(stats.generatedAt.formatted())
                    """
                    showingStats = true
                }
                
                if #available(iOS 16.0, *) {
                    NavigationLink("Open Dashboard") {
                        BackgroundTimeDashboard()
                    }
                }
                
                Button("Export Data for Analysis") {
                    exportBackgroundTaskData()
                }
                
                Button("Clear All Data") {
                    BackgroundTime.shared.clearAllEvents()
                }
            }
        }
        .alert("Background Task Statistics", isPresented: $showingStats) {
            Button("OK") { }
        } message: {
            Text(statsText)
        }
    }
    
    private func exportBackgroundTaskData() {
        let dashboardData = BackgroundTime.shared.exportDataForDashboard()
        
        // Convert to JSON for sharing
        do {
            let jsonData = try JSONEncoder().encode(dashboardData)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            
            // Share via activity sheet or save to file
            let activityController = UIActivityViewController(
                activityItems: [jsonString],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(activityController, animated: true)
            }
        } catch {
            print("Failed to export data: \(error)")
        }
    }
}
```

### 4. Remote Dashboard Integration

#### Backend Endpoint Setup
Your backend should accept POST requests to `/api/background-tasks/upload` with this structure:

```json
{
  "statistics": {
    "totalTasksScheduled": 150,
    "totalTasksExecuted": 140,
    "totalTasksCompleted": 135,
    "totalTasksFailed": 5,
    "totalTasksExpired": 10,
    "averageExecutionTime": 4.2,
    "successRate": 0.9,
    "executionsByHour": {
      "9": 15,
      "14": 25,
      "18": 30
    },
    "errorsByType": {
      "Network timeout": 3,
      "Memory pressure": 2
    },
    "lastExecutionTime": "2024-09-19T14:30:00Z",
    "generatedAt": "2024-09-19T15:00:00Z"
  },
  "events": [...],
  "timeline": [...],
  "systemInfo": {...},
  "generatedAt": "2024-09-19T15:00:00Z"
}
```

#### Enable Remote Sync
```swift
let config = BackgroundTimeConfiguration(
    apiEndpoint: URL(string: "https://your-dashboard.com/api"),
    enableNetworkSync: true
)

BackgroundTime.shared.initialize(configuration: config)

// Manual sync (optional)
Task {
    try await BackgroundTime.shared.syncWithDashboard()
}
```

### 5. Production Considerations

#### Info.plist Configuration
Make sure your background modes are properly configured:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>background-app-refresh</string>
    <string>background-processing</string>
</array>

<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>your.app.refresh</string>
    <string>your.app.processing</string>
</array>
```

#### Performance Impact
The SDK is designed to be lightweight:
- Minimal memory footprint (~1MB)
- Asynchronous operations to avoid blocking main thread
- Configurable data retention limits
- Efficient JSON serialization

#### Privacy Considerations
- All data stays on device by default
- No personal user data is collected
- Only technical background task metrics are tracked
- Optional remote sync can be disabled

### 6. Testing Your Integration

#### Debug Verification
1. **Check Initialization**: Verify SDK initializes without errors
2. **Trigger Background Tasks**: Use your app's background functionality
3. **View Dashboard**: Check that events are being recorded
4. **Export Data**: Verify data structure is correct

#### Test Script Example
```swift
#if DEBUG
extension YourApp {
    func testBackgroundTimeIntegration() {
        // Verify SDK is initialized
        let stats = BackgroundTime.shared.getCurrentStats()
        print("SDK initialized. Events count: \(BackgroundTime.shared.getAllEvents().count)")
        
        // Test background task scheduling (this will be automatically tracked)
        scheduleTestBackgroundTask()
        
        // Check data export
        let dashboardData = BackgroundTime.shared.exportDataForDashboard()
        print("Dashboard data contains \(dashboardData.events.count) events")
    }
    
    private func scheduleTestBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: "test-task")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Test background task scheduled")
        } catch {
            print("Failed to schedule test task: \(error)")
        }
    }
}
#endif
```

### 7. Monitoring and Alerts

#### Custom Alerts Based on Metrics
```swift
extension BackgroundTime {
    func checkForIssues() -> [String] {
        let stats = getCurrentStats()
        var issues: [String] = []
        
        // Low success rate
        if stats.successRate < 0.8 {
            issues.append("Background task success rate is low: \(String(format: "%.1f%%", stats.successRate * 100))")
        }
        
        // High failure rate
        let failureRate = stats.totalTasksExecuted > 0 ? 
            Double(stats.totalTasksFailed) / Double(stats.totalTasksExecuted) : 0
        if failureRate > 0.2 {
            issues.append("Background task failure rate is high: \(String(format: "%.1f%%", failureRate * 100))")
        }
        
        // Long execution times
        if stats.averageExecutionTime > 25.0 {
            issues.append("Background tasks taking too long: \(String(format: "%lld", stats.averageExecutionTime)) average")
        }
        
        // No recent executions
        if let lastExecution = stats.lastExecutionTime,
           Date().timeIntervalSince(lastExecution) > 86400 { // 24 hours
            issues.append("No background tasks executed in the last 24 hours")
        }
        
        return issues
    }
}

// Usage in your app
func performHealthCheck() {
    let issues = BackgroundTime.shared.checkForIssues()
    if !issues.isEmpty {
        // Log to your analytics service
        for issue in issues {
            print("Background Task Issue: \(issue)")
            // FirebaseAnalytics.Analytics.logEvent("background_task_issue", parameters: ["issue": issue])
        }
    }
}
```

### 8. Troubleshooting Common Issues

#### SDK Not Recording Events
```swift
// Verify initialization
if BackgroundTime.shared.getCurrentStats().generatedAt == nil {
    print("❌ BackgroundTime SDK may not be properly initialized")
} else {
    print("✅ BackgroundTime SDK is working")
}
```

#### Dashboard Not Showing Data
- Ensure iOS 16+ for full dashboard functionality
- Check that background tasks are actually being scheduled and executed
- Verify events are being recorded: `BackgroundTime.shared.getAllEvents().count`

#### Network Sync Issues
```swift
// Test network connectivity
Task {
    do {
        try await BackgroundTime.shared.syncWithDashboard()
        print("✅ Network sync successful")
    } catch {
        print("❌ Network sync failed: \(error)")
    }
}
```

## Example Production Setup

Here's a complete example of how to set up BackgroundTime in a production app:

```swift
// App.swift
import SwiftUI
import BackgroundTime
import os.log

@main
struct ProductionApp: App {
    private let logger = Logger(subsystem: "ProductionApp", category: "App")
    
    init() {
        setupBackgroundMonitoring()
        registerBackgroundTasks()
    }
    
    private func setupBackgroundMonitoring() {
        #if DEBUG
        let config = BackgroundTimeConfiguration(
            maxStoredEvents: 500,
            enableDetailedLogging: true
        )
        #else
        let config = BackgroundTimeConfiguration(
            maxStoredEvents: 2000,
            apiEndpoint: URL(string: "https://api.yourapp.com/background-monitoring"),
            enableNetworkSync: true,
            enableDetailedLogging: false
        )
        #endif
        
        BackgroundTime.shared.initialize(configuration: config)
        logger.info("BackgroundTime SDK initialized for \(config.enableNetworkSync ? "production" : "development")")
    }
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.yourapp.refresh", using: nil) { task in
            handleAppRefresh(task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.yourapp.sync", using: nil) { task in
            handleDataSync(task as! BGProcessingTask)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await performInitialHealthCheck()
                }
        }
    }
    
    private func performInitialHealthCheck() async {
        // Check background task health after app launch
        await Task.sleep(for: .seconds(5)) // Wait for initialization
        
        let issues = BackgroundTime.shared.checkForIssues()
        if !issues.isEmpty {
            logger.warning("Background task issues detected: \(issues.joined(separator: ", "))")
        }
    }
}
```

This production setup provides comprehensive monitoring while maintaining performance and respecting user privacy.

## Next Steps

1. **Deploy**: Integrate the SDK into your app
2. **Monitor**: Watch the dashboard for patterns and issues
3. **Optimize**: Use insights to improve background task performance
4. **Scale**: Set up remote dashboard for team-wide monitoring

The BackgroundTime SDK will help you build more reliable background processing and provide valuable insights into your app's behavior in production.
