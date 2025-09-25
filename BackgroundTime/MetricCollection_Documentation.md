//
//  MetricCollection_Documentation.md
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/25/25.
//

# Enhanced Metric Collection System

## Overview

The BackgroundTime framework now includes comprehensive metric collection capabilities that track task execution, system resources, network usage, and performance metrics. This system integrates with Apple's MetricKit for production-grade metric aggregation and reporting.

## Key Features

### ✅ Task Execution Duration & Success/Failure Rates
- Automatic tracking of task execution times
- Success/failure rate calculation with error categorization
- Scheduling latency measurement from task submission to execution

### ✅ CPU Usage, Memory Consumption & Energy Impact
- Real-time CPU usage monitoring during task execution
- Peak memory usage tracking
- Energy impact categorization (Very Low to Very High)
- Integration with system performance APIs

### ✅ Network Request Patterns & Data Transfer
- Network request counting and data volume tracking
- Connection reliability measurement
- Latency monitoring for network operations
- Data usage categorization

### ✅ System Conditions Monitoring
- Battery level and charging state tracking
- Low Power Mode activation detection
- Thermal state monitoring (Nominal, Fair, Serious, Critical)
- Available memory and disk space tracking

### ✅ BGTaskScheduler Error Categorization
- Comprehensive error categorization system
- Error severity assessment (Low, Medium, High, Critical)
- Retry recommendations based on error type
- Structured error metadata collection

### ✅ MetricKit Integration
- Automatic collection of system-wide metrics
- CPU, memory, network, and animation metrics
- Diagnostic payload processing for crash and hang detection
- Production-ready metric aggregation

## System Architecture

```
┌─────────────────────────┐    ┌──────────────────────────┐
│   BGTaskScheduler       │    │  BackgroundTaskTracker   │
│   (Method Swizzling)    │───▶│  (Public API)            │
└─────────────────────────┘    └──────────────────────────┘
                │                           │
                ▼                           ▼
┌─────────────────────────────────────────────────────────┐
│            MetricCollectionManager                      │
│  • Task lifecycle tracking                             │
│  • Performance monitoring                              │
│  • System resource monitoring                         │
│  • Network metrics collection                         │
│  • MetricKit integration                              │
└─────────────────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│            BackgroundTaskDataStore                      │
│  • Thread-safe event storage                          │
│  • Circular buffer implementation                     │
│  • Performance-optimized access                       │
└─────────────────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│          MetricAggregationService                      │
│  • Report generation (Daily/Weekly/Monthly)           │
│  • Trend analysis                                     │
│  • Export capabilities (JSON/CSV)                     │
└─────────────────────────────────────────────────────────┘
```

## Usage Guide

### 1. Automatic Tracking (Recommended)

The framework automatically tracks BGTaskScheduler operations through method swizzling:

```swift
// Your existing BGTaskScheduler code works unchanged
let request = BGProcessingTaskRequest(identifier: "com.yourapp.refresh")
request.requiresNetworkConnectivity = true

try BGTaskScheduler.shared.submit(request) // Automatically tracked
```

### 2. Manual Task Execution Tracking

Use `BackgroundTaskTracker` for detailed lifecycle management:

```swift
import BackgroundTime

func performBackgroundRefresh(task: BGTask) {
    BackgroundTaskTracker.shared.executeBGTask(task) {
        // Your background task logic
        try await refreshData()
        try await syncToServer()
    }
}

// Or manual control:
func manualTaskExecution() async {
    let taskId = "com.yourapp.manual-task"
    let tracker = BackgroundTaskTracker.shared
    
    tracker.startExecution(for: taskId)
    
    do {
        try await performWork()
        tracker.completeExecution(for: taskId)
    } catch {
        tracker.failExecution(for: taskId, error: error)
    }
}
```

### 3. Network Request Tracking

Track network operations during background tasks:

```swift
func performDataSync(task: BGTask) {
    let tracker = BackgroundTaskTracker.shared
    
    tracker.executeBGTask(task) {
        let data = try await fetchDataFromAPI()
        
        tracker.recordNetworkRequest(
            for: task.identifier,
            bytesTransferred: Int64(data.count),
            success: true,
            latency: 0.5
        )
    }
}
```

### 4. Custom Metadata Addition

Add custom metadata to your tasks:

```swift
func performCustomTask(task: BGTask) {
    let tracker = BackgroundTaskTracker.shared
    
    tracker.executeBGTask(task) {
        tracker.addMetadata(for: task.identifier, key: "sync_type", value: "incremental")
        
        let result = try await syncData()
        
        tracker.addMetadata(for: task.identifier, key: "records_processed", value: result.count)
    }
}
```

## Metric Reports

### Generating Reports

```swift
let aggregationService = MetricAggregationService.shared

// Generate different types of reports
let dailyReport = await aggregationService.generateDailyReport()
let weeklyReport = await aggregationService.generateWeeklyReport()
let monthlyReport = await aggregationService.generateMonthlyReport()

// Custom time range
let customRange = DateInterval(start: startDate, end: endDate)
let customReport = await aggregationService.generateReport(for: customRange)
```

### Report Contents

Each report includes:

- **Task Metrics**: Execution counts, success rates, duration statistics
- **Performance Metrics**: CPU usage, memory consumption, energy impact
- **System Metrics**: Battery conditions, thermal state, resource availability
- **Network Metrics**: Request patterns, data transfer, connection reliability
- **Error Metrics**: Error categorization, severity distribution, trends

### Exporting Data

```swift
// Export as JSON
let jsonData = try aggregationService.exportReportAsJSON(report)

// Export as CSV
let csvString = aggregationService.exportReportAsCSV(report)
```

## Error Categorization System

The framework categorizes errors into several categories:

### Error Categories
- **Authorization**: Permission-related errors
- **Quota**: Resource limit exceeded
- **System**: System-level issues
- **Configuration**: App configuration problems
- **Network**: Connectivity issues
- **Timeout**: Time-based failures
- **Unavailable**: Service unavailability

### Error Severity Levels
- **Low**: Minor issues with minimal impact
- **Medium**: Moderate issues affecting functionality
- **High**: Significant problems requiring attention
- **Critical**: Severe issues requiring immediate action

### Example Error Analysis

```swift
let error = // Some BGTaskScheduler error
let categorization = BGTaskSchedulerErrorCategorizer.categorize(error)

print("Category: \(categorization.category)")
print("Severity: \(categorization.severity)")
print("Retryable: \(categorization.isRetryable)")
print("Suggested Action: \(categorization.suggestedAction)")
```

## MetricKit Integration

The framework automatically subscribes to MetricKit updates:

### Collected Metrics
- **CPU Metrics**: Total CPU time, instructions executed
- **Memory Metrics**: Peak memory usage, average suspended memory
- **Disk Metrics**: Cumulative logical writes
- **Network Metrics**: WiFi and cellular data transfer
- **Display Metrics**: Average pixel luminance
- **Animation Metrics**: Scroll hitch time ratio
- **Launch Metrics**: Time to first draw
- **Responsiveness Metrics**: Application hang time
- **Location Metrics**: Location accuracy time breakdowns

### Diagnostic Data
- **CPU Exception Diagnostics**: Exception codes and signals
- **Disk Write Exception Diagnostics**: Excessive write operations
- **Hang Diagnostics**: Application hang duration
- **Crash Diagnostics**: Crash information and stack traces

## Performance Considerations

### Memory Management
- Uses circular buffer for efficient memory usage
- Configurable storage limits to prevent memory bloat
- Thread-safe operations with reader-writer locks

### CPU Efficiency
- Minimal overhead on background task execution
- Asynchronous metric collection
- Batch processing for better performance

### Storage Optimization
- Automatic cleanup of old metrics
- Compressed storage for historical data
- Efficient querying with indexed access patterns

## Best Practices

### 1. Configuration
```swift
// Configure storage limits during app initialization
BackgroundTaskDataStore.shared.configure(maxStoredEvents: 5000)
```

### 2. Monitoring
```swift
// Check active task executions
let activeCount = BackgroundTaskTracker.shared.activeTaskCount
let activeTasks = BackgroundTaskTracker.shared.activeTaskIdentifiers
```

### 3. Cleanup
```swift
// Clean up stale executions if needed (use sparingly)
BackgroundTaskTracker.shared.cleanupStaleExecutions()
```

### 4. Error Handling
Always handle errors gracefully and provide meaningful error messages for better categorization.

## Troubleshooting

### Common Issues

1. **MetricKit Not Available**
   - MetricKit requires iOS 13+ and may not be available on all devices
   - Check `MXMetricManager.makeMetricsAvailable()` before use

2. **High Memory Usage**
   - Reduce `maxStoredEvents` in configuration
   - Implement more frequent data cleanup

3. **Task Not Tracked**
   - Ensure `startExecution` is called before task work begins
   - Check that task identifiers match between start and completion

### Debug Information

Enable debug logging:
```swift
// Logs are automatically created with os.log
// View in Console app or Xcode debug console
// Subsystem: "BackgroundTime"
// Categories: "MetricCollection", "TaskTracker", "Swizzler", etc.
```

## API Reference

### Core Classes
- `MetricCollectionManager`: Central metric collection coordinator
- `BackgroundTaskTracker`: Public API for task lifecycle tracking
- `MetricAggregationService`: Report generation and data analysis
- `BGTaskSchedulerSwizzler`: Automatic BGTaskScheduler monitoring

### Data Models
- `PerformanceMetrics`: CPU, memory, and energy measurements
- `SystemResourceMetrics`: Battery, thermal, and resource information
- `NetworkMetrics`: Network request and transfer statistics
- `MetricAggregationReport`: Comprehensive metric reports

### Error Handling
- `BGTaskSchedulerErrorCategorizer`: Error analysis and categorization
- `BackgroundTaskError`: Custom error types with detailed information

This comprehensive metric collection system provides deep insights into your app's background task performance while maintaining excellent performance and minimal overhead.