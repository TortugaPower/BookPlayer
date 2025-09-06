//
//  ListStateManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 21/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

@Observable
final class ListStateManager {
  enum Scope: Hashable {
    case all
    case path(String)
  }

  private(set) var globalToken: Int = 0
  private var tokens: [Scope: Int] = [:]
  private var payloads: [Scope: Int] = [:]

  public var isSearching = false
  public var isEditing = false

  func reloadAll(padding: Int = 0) {
    payloads[.all] = padding
    globalToken += 1
  }

  func reload(_ scope: Scope, padding: Int = 0) {
    payloads[scope] = padding
    tokens[scope, default: 0] += 1
  }

  func token(for scope: Scope) -> Int {
    switch scope {
    case .all:
      return globalToken
    default:
      return tokens[scope, default: 0]
    }
  }

  func padding(for scope: Scope) -> Int { payloads[scope] ?? 0 }
}
