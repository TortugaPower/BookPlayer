//
//  KeychainServiceMock.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-22.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit

class KeychainServiceMock: KeychainServiceProtocol {
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  
  var entries: [BookPlayerKit.KeychainKeys: Data] = [:]
  
  func set(_ value: String, key: BookPlayerKit.KeychainKeys) throws {
    try setInternal(value, key: key)
  }
  func set<T>(_ value: T, key: BookPlayerKit.KeychainKeys) throws where T : Encodable {
    try setInternal(value, key: key)
  }
  private func setInternal<T>(_ value: T, key: BookPlayerKit.KeychainKeys) throws where T : Encodable {
    entries[key] = try encoder.encode(value)
  }
  
  func get(_ key: BookPlayerKit.KeychainKeys) throws -> String? {
    return try getInternal(key)
  }
  func get<T>(_ key: BookPlayerKit.KeychainKeys) throws -> T? where T : Decodable {
    return try getInternal(key)
  }
  private func getInternal<T>(_ key: BookPlayerKit.KeychainKeys) throws -> T? where T : Decodable {
    guard let data = entries[key] else {
      return nil
    }
    return try decoder.decode(T.self, from: data)
  }
  
  func remove(_ key: BookPlayerKit.KeychainKeys) throws {
    entries.removeValue(forKey: key)
  }
}
