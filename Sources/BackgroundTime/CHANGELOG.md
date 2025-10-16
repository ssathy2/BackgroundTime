# Changelog

All notable changes to BackgroundTime SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0-beta] - 2025-01-16

### Added
- Initial beta release
- Automatic background task monitoring via method swizzling
- SwiftUI dashboard with 4 tabs: Overview, Timeline, Performance, Errors
- Support for iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, visionOS 1+
- Comprehensive test suite using Swift Testing framework
- Zero-configuration setup - just initialize and go
- Export functionality for external dashboards
- Thread-safe data storage and access
- Real-time performance metrics and analytics

### Features
- **Automatic Tracking**: Zero-code integration with method swizzling
- **Rich Dashboard**: 4-tab SwiftUI interface with charts and analytics
- **Performance Metrics**: Success rates, execution patterns, error analysis
- **System Context**: Battery level, low power mode impact tracking
- **Export Capabilities**: JSON export for custom dashboard integration

### Supported Background Task Types
- BGAppRefreshTask
- BGProcessingTask  
- Continuous background tasks (iOS 26.0+)
- All standard BackgroundTasks framework operations

### Dashboard Requirements
- iOS 16.0+ (for Swift Charts framework)
- Graceful fallback for older iOS versions