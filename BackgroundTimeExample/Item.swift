//
//  Item.swift
//  BackgroundTimeExample
//
//  Created by Siddharth Sathyam on 9/19/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
