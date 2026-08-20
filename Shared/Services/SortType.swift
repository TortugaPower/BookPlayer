//
//  SortType.swift
//  BookPlayer
//
//  Created by gianni.carlo on 21/10/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import CoreData
import Foundation

public enum SortType: String, Codable, CaseIterable {
  case metadataTitle
  case fileName
  case mostRecent

  func fetchProperties() -> [String] {
    var properties = [
      #keyPath(LibraryItem.relativePath),
      #keyPath(LibraryItem.orderRank)
    ]

    switch self {
    case .metadataTitle:
      properties.append(#keyPath(LibraryItem.title))
    case .fileName:
      properties.append(#keyPath(LibraryItem.originalFileName))
    case .mostRecent:
      properties.append(#keyPath(LibraryItem.lastPlayDate))
    }
    return properties
  }

  /// Fetch-time sort descriptors for this rule — the query-time counterpart of
  /// `sortItems(_:)`, pinned equivalent by `QueryTimeSortSpikeTests`.
  /// `localizedStandardCompare:` is one of the selectors the SQLite store
  /// evaluates natively, and SQLite sorts NULL last under DESC, matching
  /// `sortItems`' `lastPlayDate ?? .distantPast`. The trailing `orderRank`
  /// tie-breaker keeps equal keys in the latent custom order and makes
  /// pagination deterministic (the in-memory sort was not stable).
  var sortDescriptors: [NSSortDescriptor] {
    let primary: NSSortDescriptor
    switch self {
    case .metadataTitle:
      primary = NSSortDescriptor(
        key: #keyPath(LibraryItem.title),
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare(_:))
      )
    case .fileName:
      primary = NSSortDescriptor(
        key: #keyPath(LibraryItem.originalFileName),
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare(_:))
      )
    case .mostRecent:
      primary = NSSortDescriptor(key: #keyPath(LibraryItem.lastPlayDate), ascending: false)
    }
    return [
      primary,
      NSSortDescriptor(key: #keyPath(LibraryItem.orderRank), ascending: true),
    ]
  }

  func sortItems(_ items: [LibraryItem]) -> [LibraryItem] {
    switch self {
    case .fileName:
      return items.sorted { a, b in
        a.originalFileName.localizedStandardCompare(b.originalFileName)
        == ComparisonResult.orderedAscending
      }
    case .metadataTitle:
      return items.sorted { a, b in
        a.title.localizedStandardCompare(b.title)
        == ComparisonResult.orderedAscending
      }
    case .mostRecent:
      let distantPast = Date.distantPast
      return items.sorted { a, b in
        let t1 = a.lastPlayDate ?? distantPast
        let t2 = b.lastPlayDate ?? distantPast
        return t1 > t2
      }
    }
  }
}

/// User-facing sort state for a library location.
///
/// Either an automatic rule (auto-sort by some `SortType`), or `.custom`
/// (no automatic sorting; respect manual order).
public enum EffectiveSort: Equatable {
  case automatic(SortType)
  case custom

  /// Stable string representation for UserDefaults / server storage.
  /// Returns the SortType raw value when automatic, or "custom".
  public var rawValue: String {
    switch self {
    case .automatic(let sort): return sort.rawValue
    case .custom: return "custom"
    }
  }

  public init?(rawValue: String) {
    if rawValue == "custom" {
      self = .custom
      return
    }
    if let sort = SortType(rawValue: rawValue) {
      self = .automatic(sort)
      return
    }
    return nil
  }
}

