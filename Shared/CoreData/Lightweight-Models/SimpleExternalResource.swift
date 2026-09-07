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
  /// Whether this link points at a server the user connects to, as opposed to a metadata
  /// service like Hardcover that has no host and streams nothing.
  ///
  /// The switch has NO `default` on purpose: this is the one place the question is answered,
  /// so adding a provider case becomes a compile error here and whoever adds it has to say
  /// which side it falls on.
  public var isMediaServer: Bool {
    switch ExternalResource.ProviderName(rawValue: providerName) {
    case .jellyfin, .audiobookshelf: true
    case .hardcover: false
    // A providerName this build doesn't know: not streamable, since building a URL for it
    // would require provider-specific knowledge we don't have.
    case nil: false
    }
  }
}

extension Array where Element == SimpleExternalResource {
  /// The item's media-server links, in no particular order.
  public var mediaServerResources: [SimpleExternalResource] {
    filter(\.isMediaServer)
  }

  /// The link that decides streaming for the item, or nil if none can.
  ///
  /// Deterministic: the source set is UNORDERED, so an item linked to two streaming providers
  /// would otherwise resolve to whichever the set yields first, varying between launches.
  /// Stable (providerName, providerId) order pins it.
  public var streamingResource: SimpleExternalResource? {
    mediaServerResources
      .sorted { ($0.providerName, $0.providerId) < ($1.providerName, $1.providerId) }
      .first(where: { $0.syncStatus != ExternalResource.SyncStatus.notSynced.rawValue })
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
