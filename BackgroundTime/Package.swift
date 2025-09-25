// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BackgroundTime",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .tvOS(.v14),
        .watchOS(.v7),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "BackgroundTime",
            targets: ["BackgroundTime"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        .target(
            name: "BackgroundTime",
            dependencies: [],
            path: "Sources/BackgroundTime",
            sources: [
                "BackgroundTime.swift",
                "BackgroundTimeConfiguration.swift",
                "BackgroundTimeModels.swift",
                "BackgroundTaskDataStore.swift",
                "NetworkManager.swift",
                "BGTaskSchedulerSwizzler.swift",
                "BGTaskSwizzler.swift",
                "CircularBuffer.swift",
                "ThreadSafeAccessManager.swift",
                "BackgroundTimeDashboard.swift",
                "DashboardViewModel.swift"
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "BackgroundTimeTests",
            dependencies: ["BackgroundTime"],
            path: "Tests/BackgroundTimeTests",
            sources: [
                "BackgroundTimeSDKTests.swift",
                "CircularBufferTests.swift",
                "ThreadSafeDataStoreTests.swift",
                "PerformanceTests.swift"
            ]
        ),
    ]
)