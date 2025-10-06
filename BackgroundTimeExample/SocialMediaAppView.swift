//
//  SocialMediaAppView.swift
//  BackgroundTimeExample
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import SwiftUI
import SwiftData
import BackgroundTime

struct SocialMediaAppView: View {
    @EnvironmentObject var backgroundManager: SocialMediaBackgroundManager
    @Environment(\.modelContext) private var modelContext
    @Query private var posts: [SocialMediaPost]
    @Query private var messages: [ChatMessage]
    @State private var selectedTab = 0
    @State private var showingDashboard = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Feed Tab
            NavigationStack {
                FeedView(posts: posts)
                    .navigationTitle("Feed")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Dashboard") {
                                showingDashboard = true
                            }
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Refresh") {
                                Task {
                                    await backgroundManager.manualRefreshFeed()
                                }
                            }
                        }
                    }
            }
            .tabItem {
                Label("Feed", systemImage: "house.fill")
            }
            .tag(0)
            
            // Chat Tab
            NavigationStack {
                ChatView(messages: messages)
                    .navigationTitle("Messages")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Sync") {
                                Task {
                                    await backgroundManager.manualSyncChat()
                                }
                            }
                        }
                    }
            }
            .tabItem {
                Label("Chat", systemImage: "message.fill")
            }
            .tag(1)
            
            // Test Controls Tab
            NavigationStack {
                TestControlsView()
                    .navigationTitle("Test Controls")
                    .environmentObject(backgroundManager)
            }
            .tabItem {
                Label("Test", systemImage: "wrench.fill")
            }
            .tag(2)
        }
        .sheet(isPresented: $showingDashboard) {
            if #available(iOS 16.0, *) {
                BackgroundTimeDashboard()
            } else {
                Text("Dashboard requires iOS 16+")
                    .padding()
            }
        }
    }
}

struct FeedView: View {
    let posts: [SocialMediaPost]
    
    var body: some View {
        List {
            if posts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "rectangle.stack")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("No posts yet")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text("Pull to refresh or wait for background updates")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                ForEach(posts.sorted(by: { $0.createdAt > $1.createdAt })) { post in
                    PostRowView(post: post)
                }
            }
        }
        .refreshable {
            // This will trigger through the background manager
        }
    }
}

struct PostRowView: View {
    let post: SocialMediaPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(post.author)
                    .font(.headline)
                
                Spacer()
                
                Text(post.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(post.content)
                .font(.body)
            
            if !post.imageURL.isEmpty {
                AsyncImage(url: URL(string: post.imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                }
                .frame(height: 200)
                .clipped()
                .cornerRadius(8)
            }
            
            HStack {
                Button(action: {}) {
                    Label("\(post.likes)", systemImage: "heart")
                }
                
                Button(action: {}) {
                    Label("\(post.comments)", systemImage: "bubble")
                }
                
                Spacer()
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct ChatView: View {
    let messages: [ChatMessage]
    @State private var newMessage = ""
    
    var body: some View {
        VStack {
            List {
                if messages.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "message")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        
                        Text("No messages yet")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text("Background sync will fetch new messages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    ForEach(messages.sorted(by: { $0.timestamp < $1.timestamp })) { message in
                        MessageRowView(message: message)
                    }
                }
            }
            
            // Message input
            HStack {
                TextField("Type a message...", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Send") {
                    // This would normally send the message
                    newMessage = ""
                }
                .disabled(newMessage.isEmpty)
            }
            .padding()
        }
    }
}

struct MessageRowView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(message.sender.prefix(1))
                        .foregroundColor(.white)
                        .font(.caption)
                        .fontWeight(.medium)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.sender)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(message.content)
                    .font(.body)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TestControlsView: View {
    @EnvironmentObject var backgroundManager: SocialMediaBackgroundManager
    @State private var showingStats = false
    
    var body: some View {
        List {
            Section("Manual Controls") {
                Button("Trigger Feed Refresh") {
                    Task {
                        await backgroundManager.manualRefreshFeed()
                    }
                }
                
                Button("Trigger Chat Sync") {
                    Task {
                        await backgroundManager.manualSyncChat()
                    }
                }
                
                Button("Schedule Media Download") {
                    Task {
                        backgroundManager.scheduleMediaDownload()
                    }
                }
            }
            
            Section("Background Task Testing") {
                Button("Schedule App Refresh Task") {
                    backgroundManager.scheduleAppRefreshTask()
                }
                
                Button("Schedule Processing Task") {
                    backgroundManager.scheduleMediaDownload()
                }
                
                Button("Cancel All Tasks") {
                    backgroundManager.cancelAllBackgroundTasks()
                }
            }
            
            Section("SDK Testing") {
                Button("View Current Stats") {
                    showingStats = true
                }
                
                Button("Clear All Data") {
                    backgroundManager.clearAllSDKData()
                }
                
                Button("Export Data") {
                    let data = BackgroundTime.shared.exportDataForDashboard()
                    print("Exported \(data.events.count) events")
                }
            }
        }
        .alert("Current Stats", isPresented: $showingStats) {
            Button("OK") { }
        } message: {
            let stats = BackgroundTime.shared.getCurrentStats()
            Text("""
            Total Executed: \(stats.totalTasksExecuted)
            Success Rate: \(String(format: "%.1f%%", stats.successRate * 100))
            Average Duration: \(String(format: "%.2fs", stats.averageExecutionTime))
            Failed Tasks: \(stats.totalTasksFailed)
            """)
        }
    }
}

#Preview {
    SocialMediaAppView()
        .environmentObject(SocialMediaBackgroundManager())
}
