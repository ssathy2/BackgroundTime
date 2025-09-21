//
//  SocialMediaModels.swift
//  BackgroundTimeExample
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Foundation
import SwiftData

@Model
class SocialMediaPost {
    var id: UUID
    var author: String
    var content: String
    var imageURL: String
    var likes: Int
    var comments: Int
    var createdAt: Date
    
    init(id: UUID = UUID(), author: String, content: String, imageURL: String = "", likes: Int = 0, comments: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.author = author
        self.content = content
        self.imageURL = imageURL
        self.likes = likes
        self.comments = comments
        self.createdAt = createdAt
    }
}

@Model
class ChatMessage {
    var id: UUID
    var sender: String
    var content: String
    var timestamp: Date
    var isRead: Bool
    
    init(id: UUID = UUID(), sender: String, content: String, timestamp: Date = Date(), isRead: Bool = false) {
        self.id = id
        self.sender = sender
        self.content = content
        self.timestamp = timestamp
        self.isRead = isRead
    }
}