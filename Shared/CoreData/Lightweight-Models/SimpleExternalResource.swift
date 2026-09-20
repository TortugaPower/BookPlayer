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
  /// Chapters the server reported for a virtual import: set by `asVirtualImportResource`,
  /// consumed by `createExternalBook`. Import-only — `init(from: ExternalResource)` leaves it
  /// empty, because the entity has no chapter column; the rows live on the Book.
  public var chapters: [ChapterMetadata] = []
  /// Whether this item's book still has no chapters, so a refresh knows to ask its server
  /// for them. Set only by `findMediaServerResources(at:)`; `false` everywhere else, which
  /// is the safe default — it costs a book its chapters, never a wrong write.
  public var needsChapters = false

  public init(
    id: Int = 0,
    providerName: String,
    providerId: String,
    syncStatus: String,
    lastSyncedAt: Date?,
    hostId: String? = nil,
    libraryItemUuid: String? = nil,
    libraryItemName: String? = nil,
    libraryItem: SimpleLibraryItem? = nil,
    chapters: [ChapterMetadata] = [],
    needsChapters: Bool = false
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
    self.chapters = chapters
    self.needsChapters = needsChapters
  }
}

extension SimpleExternalResource {
  /// Whether this link points at a server the user connects to. The answer lives on
  /// `ExternalResource.ProviderName.isMediaServer`, the one exhaustive switch. A providerName
  /// this build doesn't know is not streamable: building a URL for it would need
  /// provider-specific knowledge we don't have.
  public var isMediaServer: Bool {
    ExternalResource.ProviderName(rawValue: providerName)?.isMediaServer ?? false
  }
}

extension Array where Element == SimpleExternalResource {
  /// The item's media-server links, in no particular order.
  public var mediaServerResources: [SimpleExternalResource] {
    filter(\.isMediaServer)
  }

  /// The item's media-server links in a stable order, for anything the user sees or hears.
  ///
  /// `mediaServerResources` filters an UNORDERED set (`resourcesArray` is `allObjects`), so an
  /// item linked to two providers would otherwise draw its glyphs — and speak their names — in
  /// whichever order the set yields, varying between launches. Same hazard `streamingResource`
  /// pins, same comparator.
  public var displayOrderedMediaServerResources: [SimpleExternalResource] {
    mediaServerResources
      .sorted { ($0.providerName, $0.providerId) < ($1.providerName, $1.providerId) }
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
