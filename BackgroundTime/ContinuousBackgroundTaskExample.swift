//
//  ContinuousBackgroundTaskExample.swift
//  BackgroundTime
//
//  Created by Siddharth Sathyam on 9/20/25.
//
//  Example showing how to integrate Continuous Background Tasks (iOS 26.0+)
//  with the BackgroundTime dashboard framework.

import UIKit
import BackgroundTasks

// MARK: - Continuous Background Task Manager (iOS 26.0+)

@available(iOS 26.0, *)
class ContinuousBackgroundTaskManager {
    static let shared = ContinuousBackgroundTaskManager()
    
    private var activeTasks: [String: BGContinuousTask] = [:]
    private let backgroundTime = BackgroundTime.shared
    
    private init() {}
    
    /// Register continuous background task identifiers
    func registerTaskIdentifiers() {
        // Register your continuous task identifiers in Info.plist first
        // Example: "com.yourapp.data-sync", "com.yourapp.location-tracking"
    }
    
    /// Start a continuous background task
    func startContinuousTask(
        identifier: String,
        expirationHandler: @escaping () -> Void = {}
    ) async throws -> BGContinuousTask {
        
        // Log task start event
        await logTaskEvent(
            identifier: identifier, 
            type: .continuousTaskStarted,
            success: true
        )
        
        let task = try await BGContinuousTask.request(identifier: identifier) { [weak self] in
            // Handle expiration
            await self?.logTaskEvent(
                identifier: identifier,
                type: .continuousTaskStopped,
                success: false,
                errorMessage: "Task expired"
            )
            expirationHandler()
        }
        
        activeTasks[identifier] = task
        return task
    }
    
    /// Pause a continuous task
    func pauseTask(identifier: String) async {
        guard let task = activeTasks[identifier] else { return }
        
        task.suspend()
        
        await logTaskEvent(
            identifier: identifier,
            type: .continuousTaskPaused,
            success: true
        )
    }
    
    /// Resume a paused task  
    func resumeTask(identifier: String) async {
        guard let task = activeTasks[identifier] else { return }
        
        task.resume()
        
        await logTaskEvent(
            identifier: identifier,
            type: .continuousTaskResumed,  
            success: true
        )
    }
    
    /// Stop a continuous task
    func stopTask(identifier: String) async {
        guard let task = activeTasks[identifier] else { return }
        
        task.setTaskCompleted(success: true)
        activeTasks.removeValue(forKey: identifier)
        
        await logTaskEvent(
            identifier: identifier,
            type: .continuousTaskStopped,
            success: true
        )
    }
    
    /// Update task progress
    func updateProgress(
        identifier: String,
        completedUnits: Int64,
        totalUnits: Int64,
        description: String? = nil
    ) async {
        await logTaskEvent(
            identifier: identifier,
            type: .continuousTaskProgress,
            success: true,
            metadata: [
                "completed_units": "\(completedUnits)",
                "total_units": "\(totalUnits)",
                "progress_description": description ?? ""
            ]
        )
    }
    
    // MARK: - Private Methods
    
    private func logTaskEvent(
        identifier: String,
        type: BackgroundTaskEventType,
        success: Bool,
        errorMessage: String? = nil,
        metadata: [String: Any] = [:]
    ) async {
        let event = BackgroundTaskEvent(
            id: UUID(),
            taskIdentifier: identifier,
            type: type,
            timestamp: Date(),
            duration: nil, // Could calculate from task lifecycle
            success: success,
            errorMessage: errorMessage,
            metadata: metadata,
            systemInfo: SystemInfo(
                backgroundAppRefreshStatus: UIApplication.shared.backgroundRefreshStatus,
                deviceModel: UIDevice.current.model,
                systemVersion: UIDevice.current.systemVersion,
                lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                batteryLevel: UIDevice.current.batteryLevel,
                batteryState: UIDevice.current.batteryState
            )
        )
        
        await backgroundTime.recordEvent(event)
    }
}

// MARK: - Example Usage

@available(iOS 26.0, *)
class ExampleContinuousTaskViewController: UIViewController {
    
    private let taskManager = ContinuousBackgroundTaskManager.shared
    private let taskIdentifier = "com.yourapp.example-continuous-task"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // Create buttons for testing continuous tasks
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let startButton = UIButton(type: .system)
        startButton.setTitle("Start Continuous Task", for: .normal)
        startButton.addTarget(self, action: #selector(startTaskTapped), for: .touchUpInside)
        
        let pauseButton = UIButton(type: .system)
        pauseButton.setTitle("Pause Task", for: .normal)
        pauseButton.addTarget(self, action: #selector(pauseTaskTapped), for: .touchUpInside)
        
        let resumeButton = UIButton(type: .system)
        resumeButton.setTitle("Resume Task", for: .normal)
        resumeButton.addTarget(self, action: #selector(resumeTaskTapped), for: .touchUpInside)
        
        let updateProgressButton = UIButton(type: .system)
        updateProgressButton.setTitle("Update Progress", for: .normal)
        updateProgressButton.addTarget(self, action: #selector(updateProgressTapped), for: .touchUpInside)
        
        let stopButton = UIButton(type: .system)
        stopButton.setTitle("Stop Task", for: .normal)
        stopButton.addTarget(self, action: #selector(stopTaskTapped), for: .touchUpInside)
        
        [startButton, pauseButton, resumeButton, updateProgressButton, stopButton].forEach {
            stackView.addArrangedSubview($0)
        }
        
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    @objc private func startTaskTapped() {
        Task {
            do {
                _ = try await taskManager.startContinuousTask(identifier: taskIdentifier) {
                    print("Task expired")
                }
                print("Continuous task started successfully")
            } catch {
                print("Failed to start continuous task: \(error)")
            }
        }
    }
    
    @objc private func pauseTaskTapped() {
        Task {
            await taskManager.pauseTask(identifier: taskIdentifier)
            print("Task paused")
        }
    }
    
    @objc private func resumeTaskTapped() {
        Task {
            await taskManager.resumeTask(identifier: taskIdentifier)
            print("Task resumed")
        }
    }
    
    @objc private func updateProgressTapped() {
        Task {
            let randomProgress = Int64.random(in: 0...100)
            await taskManager.updateProgress(
                identifier: taskIdentifier,
                completedUnits: randomProgress,
                totalUnits: 100,
                description: "Processing data..."
            )
            print("Progress updated: \(randomProgress)/100")
        }
    }
    
    @objc private func stopTaskTapped() {
        Task {
            await taskManager.stopTask(identifier: taskIdentifier)
            print("Task stopped")
        }
    }
}

// MARK: - Integration with App Delegate

@available(iOS 26.0, *)
extension AppDelegate {
    
    func applicationDidFinishLaunching(_ application: UIApplication) {
        // Register continuous task identifiers
        ContinuousBackgroundTaskManager.shared.registerTaskIdentifiers()
        
        // Initialize BackgroundTime SDK
        BackgroundTime.shared.configure(
            apiKey: "your-api-key-here",
            enableDebugLogging: true
        )
    }
    
    // Handle background task scheduling if needed
    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Your existing background fetch logic
        completionHandler(.noData)
    }
}

// MARK: - SwiftUI Integration Example

@available(iOS 26.0, *)
struct ContinuousTaskDemoView: View {
    @StateObject private var taskManager = ContinuousBackgroundTaskManager.shared
    @State private var isTaskRunning = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Continuous Background Tasks")
                .font(.title)
                .padding()
            
            Button(action: {
                if isTaskRunning {
                    stopTask()
                } else {
                    startTask()
                }
            }) {
                Text(isTaskRunning ? "Stop Task" : "Start Task")
                    .padding()
                    .background(isTaskRunning ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            Button("Update Progress") {
                updateProgress()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            // Show BackgroundTime Dashboard
            NavigationLink("View Dashboard") {
                BackgroundTimeDashboard()
            }
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
    
    private func startTask() {
        Task {
            do {
                _ = try await taskManager.startContinuousTask(
                    identifier: "com.yourapp.demo-task"
                ) {
                    isTaskRunning = false
                }
                isTaskRunning = true
            } catch {
                print("Failed to start task: \(error)")
            }
        }
    }
    
    private func stopTask() {
        Task {
            await taskManager.stopTask(identifier: "com.yourapp.demo-task")
            isTaskRunning = false
        }
    }
    
    private func updateProgress() {
        Task {
            await taskManager.updateProgress(
                identifier: "com.yourapp.demo-task",
                completedUnits: Int64.random(in: 0...100),
                totalUnits: 100,
                description: "Demo progress update"
            )
        }
    }
}