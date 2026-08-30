//
//  SimpleExternalResource.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 13/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct SimpleExternalResource: Identifiable, Equatable, Hashable {
  public let id: Int
  public let providerName: String
  public let providerId: String
  public let syncStatus: String
  public var lastSyncedAt: Date?
  public var processedFile = false
  public var hostId: String?
  public var libraryItemUuid: String?
  public var libraryItemName: String?
  public var libraryItem: SimpleLibraryItem?

  public init(
    id: Int = 0,
    providerName: String,
    providerId: String,
    syncStatus: String,
    lastSyncedAt: Date?,
    hostId: String? = nil,
    libraryItemUuid: String? = nil,
    libraryItemName: String? = nil,
    libraryItem: SimpleLibraryItem? = nil
  ) {
    self.id = id
    self.providerName = providerName
    self.providerId = providerId
    self.syncStatus = syncStatus
    self.lastSyncedAt = lastSyncedAt
    self.hostId = hostId
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
    self.processedFile = item.processedFile
    self.hostId = item.hostId
    self.libraryItemUuid = item.libraryItem?.uuid
    self.libraryItemName = item.libraryItem?.title
    self.libraryItem = (!ignoreLibraryItem && item.libraryItem != nil) ? SimpleLibraryItem(from: item.libraryItem!) : nil
  }
}


/// A staged virtual-import selection traveling AS A VALUE from the integration
/// screen that produced it to its confirmation sheet (`.sheet(item:)`), and on
/// confirm to the import bus. Value semantics keep staging owned by whoever is
/// editing it — there is no shared mutable mailbox to fall out of sync with.
public struct ExternalImportBatch: Identifiable {
  public let id = UUID()
  public var resources: [SimpleExternalResource]

  public init(resources: [SimpleExternalResource]) {
    self.resources = resources
  }
}
