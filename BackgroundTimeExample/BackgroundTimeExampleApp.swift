//
//  BackgroundTimeExampleApp.swift
//  BackgroundTimeExample
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import SwiftUI
import SwiftData
import BackgroundTime

@main
struct BackgroundTimeExampleApp: App {
    @StateObject private var backgroundManager = SocialMediaBackgroundManager()
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Initialize BackgroundTime SDK with configuration optimized for social media app
        let configuration = BackgroundTimeConfiguration(
            maxStoredEvents: 2000, // More events for social media activity
            apiEndpoint: nil, // No remote dashboard for this example
            enableNetworkSync: false,
            enableDetailedLogging: true
        )
        BackgroundTime.shared.initialize(configuration: configuration)
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SocialMediaPost.self,
            ChatMessage.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(backgroundManager)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                Task {
                    await backgroundManager.scheduleTasks()
                }
            }
        }
    }
}
