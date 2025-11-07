// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BackgroundTime",
    platforms: [
        .iOS(.v16),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
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
        // No external dependencies currently required
    ],
    targets: [
        // MARK: - Main Library Target
        .target(
            name: "BackgroundTime",
            path: "Sources/BackgroundTime",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ForwardTrailingClosures"),
                .enableUpcomingFeature("ImplicitOpenExistentials"),
                .enableUpcomingFeature("GlobalConcurrency"),
                .enableUpcomingFeature("IsolatedDefaultValues"),
                .enableUpcomingFeature("InferSendableFromCaptures"),
                .enableExperimentalFeature("StrictConcurrency"),
                .enableExperimentalFeature("GlobalActorIsolatedTypesUsability")
            ]
        ),
        
        // MARK: - Test Targets
        .testTarget(
            name: "BackgroundTimeTests",
            dependencies: ["BackgroundTime"],
            path: "Tests/BackgroundTimeTests",
            sources: [
                "BackgroundTimeSDKTests.swift",
                "CircularBufferTests.swift",
                "ThreadSafeDataStoreTests.swift",
                "PerformanceTests.swift",
                "BGTaskSwizzlerTests.swift",
                "DashboardTests.swift"
            ],
            swiftSettings: [
                .enableUpcomingFeature("IsolatedDefaultValues"),
                .enableUpcomingFeature("InferSendableFromCaptures"),
                .enableExperimentalFeature("StrictConcurrency"),
                .enableExperimentalFeature("GlobalActorIsolatedTypesUsability")
            ]
        ),
    ]
)
