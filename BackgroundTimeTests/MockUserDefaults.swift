//
//  MockUserDefaults.swift
//  BackgroundTimeTests
//
//  Created by Siddharth Sathyam on 9/26/25.
//

import Foundation

/// Mock UserDefaults for testing purposes
class MockUserDefaults: UserDefaults {
    private var storage: [String: Any] = [:]
    
    override func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }
    
    override func object(forKey defaultName: String) -> Any? {
        return storage[defaultName]
    }
    
    override func data(forKey defaultName: String) -> Data? {
        return storage[defaultName] as? Data
    }
    
    override func string(forKey defaultName: String) -> String? {
        return storage[defaultName] as? String
    }
    
    override func array(forKey defaultName: String) -> [Any]? {
        return storage[defaultName] as? [Any]
    }
    
    override func dictionary(forKey defaultName: String) -> [String : Any]? {
        return storage[defaultName] as? [String: Any]
    }
    
    override func bool(forKey defaultName: String) -> Bool {
        return storage[defaultName] as? Bool ?? false
    }
    
    override func integer(forKey defaultName: String) -> Int {
        return storage[defaultName] as? Int ?? 0
    }
    
    override func float(forKey defaultName: String) -> Float {
        return storage[defaultName] as? Float ?? 0.0
    }
    
    override func double(forKey defaultName: String) -> Double {
        return storage[defaultName] as? Double ?? 0.0
    }
    
    override func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }
    
    func clearAll() {
        storage.removeAll()
    }
}