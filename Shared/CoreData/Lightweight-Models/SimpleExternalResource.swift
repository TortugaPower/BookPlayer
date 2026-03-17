//
//  SimpleExternalResource.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 13/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation


public struct SimpleExternalResource {
  public let id: Int
  public let providerName: String?
  public let providerItemId: String?
  public let syncStatus: Bool
  public var lastSyncedAt: Date?
  public var libraryItemUuid: Int?

  public init(
    id: Int,
    providerName: String?,
    providerItemId: String?,
    syncStatus: Bool,
    lastSyncedAt: Date?,
    libraryItemUuid: Int? = nil
  ) {
    self.id = id
    self.providerName = providerName
    self.providerItemId = providerItemId
    self.syncStatus = syncStatus
    self.lastSyncedAt = lastSyncedAt
    self.libraryItemUuid = libraryItemUuid
  }
}
