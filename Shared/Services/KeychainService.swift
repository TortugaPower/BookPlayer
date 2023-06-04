//
//  KeychainService.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 24/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import Security

/// sourcery: AutoMockable
public protocol KeychainServiceProtocol {
  func setAccessToken(_ token: String) throws
  func getAccessToken() throws -> String?
  func removeAccessToken() throws
}

public class KeychainService: KeychainServiceProtocol {
  let service = Bundle.main.configurationString(for: .bundleIdentifier)
  let tokenKey = "access_token"

  public init() {}

  public func setAccessToken(_ token: String) throws {
    try self.set(token, key: tokenKey)
  }

  public func getAccessToken() throws -> String? {
    return try self.get(tokenKey)
  }

  public func removeAccessToken() throws {
    try self.remove(tokenKey)
  }

  private func get(_ key: String) throws -> String? {
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
        let data = result as? Data,
        let string = String(data: data, encoding: .utf8)
      else {
        // unexpectedError
        throw NSError(domain: NSOSStatusErrorDomain, code: -99999)
      }
      return string
    case errSecItemNotFound:
      return nil
    default:
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
  }

  private func set(_ value: String, key: String) throws {
    guard let data = value.data(using: .utf8, allowLossyConversion: false) else {
      // conversionError
      throw NSError(domain: NSOSStatusErrorDomain, code: -67594)
    }

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
        try set(value, key: key)
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
