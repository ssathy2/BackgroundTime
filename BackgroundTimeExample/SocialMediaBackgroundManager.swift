//
//  SocialMediaBackgroundManager.swift
//  BackgroundTimeExample
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Foundation
import BackgroundTasks
import SwiftData
import UIKit
import os.log
import SwiftUI
import Combine

@MainActor
class SocialMediaBackgroundManager: ObservableObject {
    private let logger = Logger(subsystem: "BackgroundTimeExample", category: "BackgroundManager")
    
    @Published var isRefreshing = false
    @Published var lastRefreshTime: Date?
    @Published var lastSyncTime: Date?
    
    private var modelContainer: ModelContainer?
    
    init() {
        setupModelContainer()
        registerBackgroundTaskHandlers()
    }
    
    private func setupModelContainer() {
        let schema = Schema([
            SocialMediaPost.self,
            ChatMessage.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            logger.error("Failed to create ModelContainer: \(error)")
        }
    }
    
    enum AppBackgroundTaskIdentifier {
        case refreshSocialFeed
        case downloadMedia
        case syncChatMessages
        
        init?(stringIdentifier: String) {
            guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return nil }
            switch stringIdentifier {
            case "\(bundleIdentifier)-refresh-social-feed":
                self = .refreshSocialFeed
            case "\(bundleIdentifier)-sync-chat-messages":
                self = .syncChatMessages
            default:
                return nil
            }
        }
        
        var description: String {
            let bundleIdentifier = Bundle.main.bundleIdentifier
            switch self {
            case .refreshSocialFeed:
                return [bundleIdentifier, "refresh-social-feed"].compactMap { $0 }.joined(separator: "-")
            case .downloadMedia:
                return [bundleIdentifier, "download-media"].compactMap { $0 }.joined(separator: "-")
            case .syncChatMessages:
                return [bundleIdentifier, "sync-chat-messages"].compactMap { $0 }.joined(separator: "-")
            }
        }
    }
    
    private func registerBackgroundTaskHandlers() {
        // Register handler for social feed refresh
        BGTaskScheduler.shared.register(forTaskWithIdentifier: AppBackgroundTaskIdentifier.refreshSocialFeed.description, using: nil) { task in
            guard let appRefreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                self.handleAppRefreshTask(appRefreshTask)
            }
        }
        
        // Register handler for media download processing
        BGTaskScheduler.shared.register(forTaskWithIdentifier: AppBackgroundTaskIdentifier.downloadMedia.description, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                self.handleProcessingTask(processingTask)
            }
        }
        
        // Register handler for chat message sync
        BGTaskScheduler.shared.register(forTaskWithIdentifier: AppBackgroundTaskIdentifier.syncChatMessages.description, using: nil) { task in
            guard let appRefreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                self.handleChatSyncTask(appRefreshTask)
            }
        }
        
        logger.info("Background task handlers registered successfully")
    }
    
    // MARK: - Background Task Handlers
    
    func handleAppRefreshTask(_ task: BGAppRefreshTask) {
        logger.info("Handling app refresh task: \(task.identifier)")
        
        task.expirationHandler = {
            self.logger.warning("App refresh task expired: \(task.identifier)")
            task.setTaskCompleted(success: false)
        }
        
        Task {
            let success: Bool
            guard let taskIdentifier = AppBackgroundTaskIdentifier(stringIdentifier: task.identifier) else {
                task.setTaskCompleted(success: false)
                return
            }
            
            switch taskIdentifier {
            case .refreshSocialFeed:
                success = await performFeedRefresh()
                task.setTaskCompleted(success: success)
                scheduleAppRefreshTask()
            case .syncChatMessages:
                success = await performChatSync()
                task.setTaskCompleted(success: success)
                scheduleChatSyncTask()
            default:
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    func handleProcessingTask(_ task: BGProcessingTask) {
        logger.info("Handling processing task: \(task.identifier)")
        
        task.expirationHandler = {
            self.logger.warning("Processing task expired: \(task.identifier)")
            task.setTaskCompleted(success: false)
        }
        
        Task {
            let success: Bool
            guard let taskIdentifier = AppBackgroundTaskIdentifier(stringIdentifier: task.identifier) else {
                task.setTaskCompleted(success: false)
                return
            }
            
            switch taskIdentifier {
            case .downloadMedia:
                success = await performMediaDownload()
                task.setTaskCompleted(success: success)
                scheduleMediaDownload()
            default:
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    func handleChatSyncTask(_ task: BGAppRefreshTask) {
        logger.info("Handling chat sync task: \(task.identifier)")
        
        task.expirationHandler = {
            self.logger.warning("Chat sync task expired: \(task.identifier)")
            task.setTaskCompleted(success: false)
        }
        
        Task {
            let success = await performChatSync()
            task.setTaskCompleted(success: success)
        }
    }
    
    // MARK: - Background Operations
    
    func refreshSocialFeed() async {
        _ = await performFeedRefresh()
    }
    
    func downloadMedia(for identifier: String) async {
        _ = await performMediaDownload()
    }
    
    private func performFeedRefresh() async -> Bool {
        isRefreshing = true
        
        do {
            // Simulate network delay
            try await Task.sleep(for: .seconds(2))
            
            // Simulate fetching new posts
            let newPosts = generateMockPosts()
            
            guard let modelContainer = modelContainer else {
                logger.error("Model container not available")
                isRefreshing = false
                return false
            }
            
            let context = ModelContext(modelContainer)
            
            for post in newPosts {
                context.insert(post)
            }
            
            try context.save()
            
            await MainActor.run {
                self.lastRefreshTime = Date()
                self.isRefreshing = false
            }
            
            logger.info("Successfully refreshed social feed with \(newPosts.count) new posts")
            return true
            
        } catch {
            logger.error("Feed refresh failed: \(error)")
            await MainActor.run {
                self.isRefreshing = false
            }
            return false
        }
    }
    
    private func performChatSync() async -> Bool {
        do {
            // Simulate network delay
            try await Task.sleep(for: .seconds(1))
            
            // Simulate fetching new messages
            let newMessages = generateMockMessages()
            
            guard let modelContainer = modelContainer else {
                logger.error("Model container not available")
                return false
            }
            
            let context = ModelContext(modelContainer)
            
            for message in newMessages {
                context.insert(message)
            }
            
            try context.save()
            
            await MainActor.run {
                self.lastSyncTime = Date()
            }
            
            logger.info("Successfully synced \(newMessages.count) new chat messages")
            return true
            
        } catch {
            logger.error("Chat sync failed: \(error)")
            return false
        }
    }
    
    private func performMediaDownload() async -> Bool {
        do {
            // Simulate downloading media files
            try await Task.sleep(for: .seconds(3))
            
            // Simulate processing downloaded media
            let mediaItems = ["image1.jpg", "image2.jpg", "video1.mp4"]
            
            for item in mediaItems {
                // Simulate processing each media item
                try await Task.sleep(for: .milliseconds(500))
                logger.info("Processed media item: \(item)")
            }
            
            logger.info("Successfully downloaded and processed \(mediaItems.count) media items")
            return true
            
        } catch {
            logger.error("Media download failed: \(error)")
            return false
        }
    }
    
    // MARK: - Task Scheduling
    
    func scheduleTasks() async {
        // Cancel any existing task requests before scheduling new ones
        BGTaskScheduler.shared.cancelAllTaskRequests()
        logger.info("Cancelled existing background tasks before scheduling new ones")
        
        scheduleAppRefreshTask()
        scheduleMediaDownload()
        scheduleChatSyncTask()
    }
    
    func scheduleAppRefreshTask() {
        let request = BGAppRefreshTaskRequest(identifier: AppBackgroundTaskIdentifier.refreshSocialFeed.description)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled app refresh task")
        } catch {
            logger.error("Failed to schedule app refresh task: \(error)")
        }
    }
    
    func scheduleChatSyncTask() {
        let request = BGAppRefreshTaskRequest(identifier: AppBackgroundTaskIdentifier.syncChatMessages.description)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 10 * 60) // 10 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled chat sync task")
        } catch {
            logger.error("Failed to schedule chat sync task: \(error)")
        }
    }
    
    func scheduleMediaDownload() {
        let request = BGProcessingTaskRequest(identifier: AppBackgroundTaskIdentifier.downloadMedia.description)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5) // 5 seconds for testing
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled immediate media download task")
        } catch {
            logger.error("Failed to schedule media download task: \(error)")
        }
    }
    
    // MARK: - Manual Operations
    
    func manualRefreshFeed() async {
        _ = await performFeedRefresh()
    }
    
    func manualSyncChat() async {
        _ = await performChatSync()
    }
    
    func cancelAllBackgroundTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        logger.info("Cancelled all background tasks")
    }
    
    func clearAllSDKData() {
        // TODO Note: SDK data clearing would typically be handled by the BackgroundTime SDK
        // if it provided a public interface for this functionality
        logger.info("SDK data clear requested")
    }
    
    // MARK: - Mock Data Generation
    
    private func generateMockPosts() -> [SocialMediaPost] {
        let authors = ["Alice", "Bob", "Charlie", "Diana", "Eve"]
        let contents = [
            "Just finished an amazing workout! 💪",
            "Beautiful sunset today 🌅",
            "Coffee and coding, perfect morning ☕️",
            "Weekend vibes! Time to relax 🏖️",
            "New recipe turned out great! 🍝",
            "Hiking adventure complete 🥾",
            "Reading a fantastic book 📚",
            "Concert was incredible! 🎵",
            "Rainy day perfect for staying in 🌧️",
            "Celebrating small wins today! 🎉"
        ]
        
        let imageURLs = [
            "https://picsum.photos/400/300?random=1",
            "https://picsum.photos/400/300?random=2",
            "https://picsum.photos/400/300?random=3",
            "",
            ""
        ]
        
        let numberOfPosts = Int.random(in: 1...3)
        var posts: [SocialMediaPost] = []
        
        for _ in 0..<numberOfPosts {
            let post = SocialMediaPost(
                author: authors.randomElement()!,
                content: contents.randomElement()!,
                imageURL: imageURLs.randomElement()!,
                likes: Int.random(in: 0...100),
                comments: Int.random(in: 0...20),
                createdAt: Date(timeIntervalSinceNow: TimeInterval.random(in: -3600...0))
            )
            posts.append(post)
        }
        
        return posts
    }
    
    private func generateMockMessages() -> [ChatMessage] {
        let senders = ["Team Lead", "Designer", "QA Tester", "Product Manager", "Developer"]
        let messages = [
            "Hey, can we review the latest changes?",
            "The design looks great! 👍",
            "Found a small bug in the login flow",
            "Meeting scheduled for 2 PM",
            "Great job on the latest release!",
            "Can you check the server logs?",
            "Testing went smoothly",
            "PR is ready for review",
            "Documentation updated",
            "Let's discuss the roadmap"
        ]
        
        let numberOfMessages = Int.random(in: 1...2)
        var chatMessages: [ChatMessage] = []
        
        for _ in 0..<numberOfMessages {
            let message = ChatMessage(
                sender: senders.randomElement()!,
                content: messages.randomElement()!,
                timestamp: Date(timeIntervalSinceNow: TimeInterval.random(in: -1800...0))
            )
            chatMessages.append(message)
        }
        
        return chatMessages
    }
}
