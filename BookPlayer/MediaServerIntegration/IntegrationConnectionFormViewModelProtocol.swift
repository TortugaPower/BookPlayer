//
//  IntegrationConnectionFormViewModelProtocol.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

struct CustomHeaderEntry: Identifiable, Equatable {
  let id: UUID
  var key: String
  var value: String

  init(id: UUID = UUID(), key: String = "", value: String = "") {
    self.id = id
    self.key = key
    self.value = value
  }
}

protocol IntegrationConnectionFormViewModelProtocol: ObservableObject {
  var serverUrl: String { get set }
  var serverName: String { get set }
  var username: String { get set }
  var password: String { get set }
  var customHeaders: [CustomHeaderEntry] { get set }
}

extension IntegrationConnectionFormViewModelProtocol {
  /// Serialize the header entries into a dictionary. Skips entries with:
  /// - an empty key or value,
  /// - characters that `URLRequest.setValue(_:forHTTPHeaderField:)` would
  ///   reject (newlines in either field, a colon in the key),
  /// - or a key of `Authorization` — which is owned by the integration itself
  ///   (Jellyfin's MediaBrowser scheme / AudiobookShelf's Bearer token) and
  ///   must not be overridden.
  /// Later duplicates of the same (trimmed) key overwrite earlier values.
  func customHeadersDictionary() -> [String: String] {
    var result: [String: String] = [:]
    for entry in customHeaders {
      let trimmedKey = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedKey.isEmpty else { continue }
      guard trimmedKey.rangeOfCharacter(from: .newlines) == nil,
        !trimmedKey.contains(":")
      else { continue }
      guard trimmedKey.caseInsensitiveCompare("Authorization") != .orderedSame else { continue }
      let trimmedValue = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedValue.isEmpty,
        trimmedValue.rangeOfCharacter(from: .newlines) == nil
      else { continue }
      result[trimmedKey] = trimmedValue
    }
    return result
  }
}
