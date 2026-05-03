//
//  PreferencesAPI.swift
//  BookPlayer
//
//  Endpoint definitions for the user-preferences server (sticky sort, etc.).
//

import Foundation

public enum PreferencesAPI {
  /// Fetch all of the user's preferences (optionally filtered by key prefix).
  case getPreferences(prefix: String?)
  /// Upsert one or more preferences (max 500 per request, server-enforced).
  case setPreferences(entries: [PreferenceEntry])
  /// Soft-delete preferences by key.
  case deletePreferences(keys: [String])
}

public struct PreferenceEntry {
  public let key: String
  public let value: [String: Any]

  public init(key: String, value: [String: Any]) {
    self.key = key
    self.value = value
  }
}

extension PreferencesAPI: Endpoint {
  public var path: String {
    return "/v1/user/preferences"
  }

  public var method: HTTPMethod {
    switch self {
    case .getPreferences:
      return .get
    case .setPreferences:
      return .patch
    case .deletePreferences:
      return .delete
    }
  }

  public var parameters: [String: Any]? {
    switch self {
    case .getPreferences(let prefix):
      if let prefix {
        return ["prefix": prefix]
      }
      return nil
    case .setPreferences(let entries):
      return [
        "entries": entries.map { ["key": $0.key, "value": $0.value] }
      ]
    case .deletePreferences(let keys):
      return ["keys": keys]
    }
  }
}
