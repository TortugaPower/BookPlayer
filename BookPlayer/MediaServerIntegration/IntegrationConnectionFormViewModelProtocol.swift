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

  /// Returns the `(key, value)` pair this entry contributes to an outgoing request,
  /// or `nil` if it should be dropped. Single source of truth for header validation,
  /// consumed by both `customHeadersDictionary()` (persistence/send) and the UI
  /// strikethrough indicator. Rules:
  /// - Key and value are trimmed of surrounding whitespace and newlines.
  /// - Empty key or empty value → dropped.
  /// - Key containing newlines or `:` → dropped (would crash `URLRequest.setValue`).
  /// - Value containing newlines → dropped (same reason).
  /// - Key of `Authorization` → dropped; owned by the integration itself
  ///   (Jellyfin's MediaBrowser scheme / AudiobookShelf's Bearer token).
  var normalized: (key: String, value: String)? {
    let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedKey.isEmpty,
      trimmedKey.rangeOfCharacter(from: .newlines) == nil,
      !trimmedKey.contains(":"),
      trimmedKey.caseInsensitiveCompare("Authorization") != .orderedSame
    else { return nil }
    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedValue.isEmpty,
      trimmedValue.rangeOfCharacter(from: .newlines) == nil
    else { return nil }
    return (trimmedKey, trimmedValue)
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
  /// Serialize the header entries into a dictionary, dropping anything
  /// `CustomHeaderEntry.normalized` rejects. Later duplicates of the same
  /// (trimmed) key overwrite earlier values.
  func customHeadersDictionary() -> [String: String] {
    var result: [String: String] = [:]
    for entry in customHeaders {
      guard let pair = entry.normalized else { continue }
      result[pair.key] = pair.value
    }
    return result
  }
}
