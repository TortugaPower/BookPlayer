//
//  SimpleExternalResource.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 13/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct SimpleExternalResource: Identifiable {
  public let id: Int
  public let providerName: String
  public let providerId: String
  public let syncStatus: String
  public var lastSyncedAt: Date?
  public var processedFile = true
  public var libraryItemUuid: String?
  public var libraryItemName: String?
  public var libraryItem: SimpleLibraryItem?

  public init(
    id: Int = 0,
    providerName: String,
    providerId: String,
    syncStatus: String,
    lastSyncedAt: Date?,
    libraryItemUuid: String? = nil,
    libraryItemName: String? = nil,
    libraryItem: SimpleLibraryItem? = nil
  ) {
    self.id = id
    self.providerName = providerName
    self.providerId = providerId
    self.syncStatus = syncStatus
    self.lastSyncedAt = lastSyncedAt
    self.libraryItemUuid = libraryItemUuid
    self.libraryItemName = libraryItemName
    self.libraryItem = libraryItem
  }
}

extension SimpleExternalResource {
  public init(from item: ExternalResource, ignoreLibraryItem: Bool = false) {
    self.id = Int(item.id)
    self.providerName = item.providerName
    self.providerId = item.providerId
    self.syncStatus = item.syncStatus
    self.lastSyncedAt = item.lastSyncedAt
    self.libraryItemUuid = item.libraryItem?.uuid
    self.libraryItemName = item.libraryItem?.title
    self.libraryItem = (!ignoreLibraryItem && item.libraryItem != nil) ? SimpleLibraryItem(from: item.libraryItem!) : nil
  }
}

