//
//  KeychainService.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 24/4/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import Foundation
import Security

public protocol KeychainServiceProtocol {
  func set(_ value: String, key: KeychainKeys) throws
  func set<T: Encodable>(_ value: T, key: KeychainKeys) throws

  func get(_ key: KeychainKeys) throws -> String?
  func get<T: Decodable>(_ key: KeychainKeys) throws -> T?
  func remove(_ key: KeychainKeys) throws
}

public enum KeychainKeys: String {
  /// Stores BookPlayer's API access token
  case token = "access_token"
  /// Stores the Jellyfin connection information (JellyfinConnectionData)
  case jellyfinConnection = "jellyfin_connection"
}

public class KeychainService: KeychainServiceProtocol {
  let service = Bundle.main.configurationString(for: .bundleIdentifier)

  private let encoder: JSONEncoder = JSONEncoder()
  private let decoder: JSONDecoder = JSONDecoder()

  public init() {}

  public func get<T: Decodable>(_ key: KeychainKeys) throws -> T? {
    guard
      let data = try getData(key.rawValue)
    else {
      return nil
    }

    return try decoder.decode(T.self, from: data)
  }

  public func get(_ key: KeychainKeys) throws -> String? {
    guard
      let data = try getData(key.rawValue)
    else {
      return nil
    }

    guard
      let string = String(data: data, encoding: .utf8)
    else {
      // unexpectedError
      throw NSError(domain: NSOSStatusErrorDomain, code: -99999)
    }

    return string
  }

  private func getData(_ key: String) throws -> Data? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecReturnData as String: true,
      kSecAttrAccount as String: key
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    switch status {
    case errSecSuccess:
      guard
        let data = result as? Data
      else {
        // unexpectedError
        throw NSError(domain: NSOSStatusErrorDomain, code: -99999)
      }
      return data
    case errSecItemNotFound:
      return nil
    default:
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
  }

  public func set<T: Encodable>(_ value: T, key: KeychainKeys) throws {
    let data = try encoder.encode(value)
    try setData(data, key: key.rawValue)
  }

  public func set(_ value: String, key: KeychainKeys) throws {
    guard let data = value.data(using: .utf8, allowLossyConversion: false) else {
      // conversionError
      throw NSError(domain: NSOSStatusErrorDomain, code: -67594)
    }

    try setData(data, key: key.rawValue)
  }

  private func setData(_ data: Data, key: String) throws {
    let searchQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true
    ]

    var status = SecItemCopyMatching(searchQuery as CFDictionary, nil)
    switch status {
    case errSecSuccess, errSecInteractionNotAllowed:
      let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: key
      ]

      let attributes: [String: Any] = [
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
      ]

#if os(iOS)
      if status == errSecInteractionNotAllowed && floor(NSFoundationVersionNumber) <= floor(NSFoundationVersionNumber_iOS_8_0) {
        try remove(key)
        try setData(data, key: key)
      } else {
        status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status != errSecSuccess {
          throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
      }
#else
      status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
      if status != errSecSuccess {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
      }
#endif
    case errSecItemNotFound:
      try self.add(data, key: key)
    default:
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
  }

  private func add(_ data: Data, key: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    if status != errSecSuccess {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
  }

  public func remove(_ key: KeychainKeys) throws {
    try remove(key.rawValue)
  }

  private func remove(_ key: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key
    ]

    let status = SecItemDelete(query as CFDictionary)
    if status != errSecSuccess && status != errSecItemNotFound {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
  }
}
