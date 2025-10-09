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
    @Published var isContinuedDataProcessing = false
    @Published var isContinuedMediaProcessing = false
    @Published var lastContinuedDataProcessingTime: Date?
    @Published var lastContinuedMediaProcessingTime: Date?
    
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
        case continuedDataProcessing
        case continuedMediaProcessing
        
        init?(stringIdentifier: String) {
            guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return nil }
            switch stringIdentifier {
            case "\(bundleIdentifier)-refresh-social-feed":
                self = .refreshSocialFeed
            case "\(bundleIdentifier)-sync-chat-messages":
                self = .syncChatMessages
            case "\(bundleIdentifier)-download-media":
                self = .downloadMedia
            case "\(bundleIdentifier)-continued-data-processing":
                self = .continuedDataProcessing
            case "\(bundleIdentifier)-continued-media-processing":
                self = .continuedMediaProcessing
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
            case .continuedDataProcessing:
                return [bundleIdentifier, "continued-data-processing"].compactMap { $0 }.joined(separator: "-")
            case .continuedMediaProcessing:
                return [bundleIdentifier, "continued-media-processing"].compactMap { $0 }.joined(separator: "-")
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
        
        // Register handler for continued data processing
        BGTaskScheduler.shared.register(forTaskWithIdentifier: AppBackgroundTaskIdentifier.continuedDataProcessing.description, using: nil) { task in
            guard let continuedTask = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                self.handleContinuedProcessingTask(continuedTask)
            }
        }
        
        // Register handler for continued media processing
        BGTaskScheduler.shared.register(forTaskWithIdentifier: AppBackgroundTaskIdentifier.continuedMediaProcessing.description, using: nil) { task in
            guard let continuedTask = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                self.handleContinuedProcessingTask(continuedTask)
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
    
    func handleContinuedProcessingTask(_ task: BGContinuedProcessingTask) {
        logger.info("Handling continued processing task: \(task.identifier)")
        
        task.expirationHandler = {
            self.logger.warning("Continued processing task expired: \(task.identifier)")
            task.setTaskCompleted(success: false)
        }
        
        Task {
            let success: Bool
            guard let taskIdentifier = AppBackgroundTaskIdentifier(stringIdentifier: task.identifier) else {
                task.setTaskCompleted(success: false)
                return
            }
            
            switch taskIdentifier {
            case .continuedDataProcessing:
                success = await performContinuedDataProcessing()
                task.setTaskCompleted(success: success)
                scheduleContinuedDataProcessing()
            case .continuedMediaProcessing:
                success = await performContinuedMediaProcessing()
                task.setTaskCompleted(success: success)
                scheduleContinuedMediaProcessing()
            default:
                task.setTaskCompleted(success: false)
            }
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
    
    private func performContinuedDataProcessing() async -> Bool {
        await MainActor.run {
            self.isContinuedDataProcessing = true
        }
        
        do {
            // Simulate long-running data processing tasks
            try await Task.sleep(for: .seconds(5))
            
            // Simulate processing large datasets
            let dataBatches = ["user_analytics", "content_indexing", "recommendation_engine", "search_optimization"]
            
            for (index, batch) in dataBatches.enumerated() {
                // Each batch takes significant time to process
                try await Task.sleep(for: .seconds(10))
                logger.info("Processed data batch \(index + 1)/\(dataBatches.count): \(batch)")
                
                // Update progress periodically
                if index % 2 == 0 {
                    logger.info("Continued data processing progress: \(Int(Double(index + 1) / Double(dataBatches.count) * 100))%")
                }
            }
            
            // Final cleanup and indexing
            try await Task.sleep(for: .seconds(3))
            logger.info("Successfully completed continued data processing for \(dataBatches.count) batches")
            
            await MainActor.run {
                self.lastContinuedDataProcessingTime = Date()
                self.isContinuedDataProcessing = false
            }
            
            return true
            
        } catch {
            logger.error("Continued data processing failed: \(error)")
            await MainActor.run {
                self.isContinuedDataProcessing = false
            }
            return false
        }
    }
    
    private func performContinuedMediaProcessing() async -> Bool {
        await MainActor.run {
            self.isContinuedMediaProcessing = true
        }
        
        do {
            // Simulate long-running media processing tasks
            try await Task.sleep(for: .seconds(2))
            
            // Simulate processing large media files
            let mediaFiles = [
                "4k_video_1.mov", "raw_image_batch_1.zip", "audio_collection.flac",
                "hdr_photos.dng", "360_video.mp4", "time_lapse_sequence.mov"
            ]
            
            for (index, file) in mediaFiles.enumerated() {
                // Each media file takes significant time to process
                let processingTime = Double.random(in: 8...15)
                try await Task.sleep(for: .seconds(processingTime))
                
                logger.info("Processed media file \(index + 1)/\(mediaFiles.count): \(file)")
                
                // Simulate additional operations like thumbnail generation, format conversion
                try await Task.sleep(for: .seconds(2))
                logger.info("Generated thumbnails and metadata for: \(file)")
                
                // Update progress
                let progress = Int(Double(index + 1) / Double(mediaFiles.count) * 100)
                logger.info("Continued media processing progress: \(progress)%")
            }
            
            // Final optimization and cleanup
            try await Task.sleep(for: .seconds(4))
            logger.info("Successfully completed continued media processing for \(mediaFiles.count) files")
            
            await MainActor.run {
                self.lastContinuedMediaProcessingTime = Date()
                self.isContinuedMediaProcessing = false
            }
            
            return true
            
        } catch {
            logger.error("Continued media processing failed: \(error)")
            await MainActor.run {
                self.isContinuedMediaProcessing = false
            }
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
        scheduleContinuedDataProcessing()
        scheduleContinuedMediaProcessing()
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
    
    func scheduleContinuedDataProcessing() {
        let request = BGContinuedProcessingTaskRequest(
            identifier: AppBackgroundTaskIdentifier.continuedDataProcessing.description,
            title: "Processing Data",
            subtitle: "Analyzing user analytics and content"
        )
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled continued data processing task")
        } catch {
            logger.error("Failed to schedule continued data processing task: \(error)")
        }
    }
    
    func scheduleContinuedMediaProcessing() {
        let request = BGContinuedProcessingTaskRequest(
            identifier: AppBackgroundTaskIdentifier.continuedMediaProcessing.description,
            title: "Processing Media",
            subtitle: "Converting and optimizing media files"
        )
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled continued media processing task")
        } catch {
            logger.error("Failed to schedule continued media processing task: \(error)")
        }
    }
    
    // MARK: - Manual Operations
    
    func manualRefreshFeed() async {
        _ = await performFeedRefresh()
    }
    
    func manualSyncChat() async {
        _ = await performChatSync()
    }
    
    func manualContinuedDataProcessing() async {
        _ = await performContinuedDataProcessing()
    }
    
    func manualContinuedMediaProcessing() async {
        _ = await performContinuedMediaProcessing()
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
            let content = contents.randomElement()!
            let post = SocialMediaPost(
                author: authors.randomElement()!,
                content: content,
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
            let sender = senders.randomElement()!
            let content = messages.randomElement()!
            let message = ChatMessage(
                sender: sender,
                content: content,
                timestamp: Date(timeIntervalSinceNow: TimeInterval.random(in: -1800...0))
            )
            chatMessages.append(message)
        }
        
        return chatMessages
    }
}
