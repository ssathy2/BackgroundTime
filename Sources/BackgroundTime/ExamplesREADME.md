# BackgroundTime SDK Example App

This example app demonstrates how to integrate BackgroundTime SDK into a social media/chat app with various background tasks.

## Overview

The example app showcases:
- **Social Media Feed**: Uses `BGAppRefreshTask` to refresh social media content
- **Media Downloads**: Uses `BGProcessingTask` for downloading images and videos  
- **Chat Sync**: Uses `BGAppRefreshTask` for synchronizing chat messages
- **BackgroundTime Dashboard**: Full integration showing monitoring capabilities

## Key Features Demonstrated

### Background Tasks
1. **Feed Refresh** (`refresh-social-feed`)
   - Updates social media feed content
   - Runs every 15 minutes when possible
   - Shows typical social media refresh patterns

2. **Media Download** (`download-media-content`)
   - Downloads images and videos for offline viewing
   - Long-running processing task
   - Demonstrates file handling in background

3. **Chat Message Sync** (`sync-chat-messages`)
   - Synchronizes chat messages with server
   - Short, frequent refresh task
   - Shows communication app patterns

### Dashboard Integration
- **Overview Tab**: Shows success rates and execution patterns
- **Timeline Tab**: Real-time view of background task events
- **Performance Tab**: Duration trends and task-specific metrics
- **Errors Tab**: Failure analysis and system constraint impacts

## Running the Example

1. **Open the Example**:
   ```bash
   cd Examples/SocialMediaApp
   open SocialMediaApp.xcodeproj
   ```

2. **Configure Background Modes**:
   - Background App Refresh is already enabled in Info.plist
   - Background task identifiers are registered

3. **Run on Device**:
   - Background tasks require a physical device
   - Simulator has limited background processing

4. **Test Background Tasks**:
   - Put app in background
   - Use Xcode debugger to trigger tasks manually
   - Check BackgroundTime dashboard for monitoring

## Code Highlights

### SDK Initialization
```swift
import BackgroundTime

@main
struct SocialMediaApp: App {
    init() {
        // Initialize BackgroundTime - automatic monitoring starts
        BackgroundTime.shared.initialize()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Background Task Registration
```swift
import BackgroundTasks

class BackgroundTaskManager {
    func registerBackgroundTasks() {
        // Register feed refresh task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "refresh-social-feed",
            using: nil
        ) { task in
            await self.handleFeedRefresh(task as! BGAppRefreshTask)
        }
        
        // Register media download task  
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "download-media-content",
            using: nil
        ) { task in
            await self.handleMediaDownload(task as! BGProcessingTask)
        }
    }
}
```

### Dashboard Integration
```swift
struct ContentView: View {
    @State private var showDashboard = false
    
    var body: some View {
        TabView {
            FeedView()
                .tabItem { Label("Feed", systemImage: "house") }
            
            ChatView()
                .tabItem { Label("Messages", systemImage: "message") }
            
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .sheet(isPresented: $showDashboard) {
            if #available(iOS 16.0, *) {
                BackgroundTimeDashboard()
            }
        }
    }
}
```

## Testing Background Tasks

### Using Xcode Debugger
1. Set breakpoints in background task handlers
2. Run app on device
3. Put app in background
4. In Xcode: Debug → Simulate Background App Refresh
5. Watch BackgroundTime dashboard for real-time updates

### Manual Testing
1. Enable Background App Refresh in Settings
2. Use the app normally (view feed, send messages, download media)
3. Put app in background for extended periods
4. Return to app and check dashboard metrics

## What You'll See in the Dashboard

### Overview Tab
- **Total Executions**: Count of background tasks that ran
- **Success Rate**: Percentage of tasks that completed successfully  
- **Average Duration**: How long tasks typically take
- **Hourly Pattern**: When background tasks run most frequently

### Timeline Tab
- Real-time stream of background task events
- Filter by task type or success/failure
- See exact timestamps and durations

### Performance Tab
- Duration trends over time
- Individual metrics for each task identifier
- Performance comparisons between task types

### Errors Tab
- Detailed failure analysis
- System constraint impacts (battery, background refresh)
- Error categorization and patterns

## Customization

You can customize the example to explore:

### Different Task Types
- Add more `BGAppRefreshTask` variations
- Experiment with `BGProcessingTask` for CPU-intensive work
- Try different scheduling patterns

### Configuration Options
```swift
let config = BackgroundTimeConfiguration(
    maxStoredEvents: 2000,
    enableDetailedLogging: true,
    enableNetworkSync: false
)

BackgroundTime.shared.initialize(configuration: config)
```

### Export Data
```swift
// Access monitoring data programmatically
let stats = BackgroundTime.shared.getCurrentStats()
let events = BackgroundTime.shared.getAllEvents()
let exportData = BackgroundTime.shared.exportDataForDashboard()
```

## Best Practices Demonstrated

1. **Efficient Background Processing**: Tasks complete quickly to avoid system termination
2. **Error Handling**: Robust error handling with proper task completion calls
3. **User Experience**: Background work doesn't interfere with foreground experience  
4. **Monitoring Integration**: BackgroundTime dashboard provides visibility without affecting performance

## Requirements

- iOS 15.0+
- Physical device for background task testing
- Background App Refresh enabled in Settings

## Next Steps

After exploring this example:
1. Integrate BackgroundTime into your own app
2. Customize the dashboard for your specific needs
3. Use the monitoring data to optimize background task performance
4. Consider adding remote dashboard sync for production monitoring

For more details, see the main README and API documentation.