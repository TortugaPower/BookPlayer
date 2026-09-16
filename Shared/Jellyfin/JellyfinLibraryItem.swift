//
//  JellyfinLibraryItem.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-26.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import JellyfinAPI

public struct JellyfinLibraryItem: IntegrationLibraryItemProtocol {
  public static func == (lhs: JellyfinLibraryItem, rhs: JellyfinLibraryItem) -> Bool {
    return lhs.id == rhs.id
  }
  
  public enum Kind {
    case userView
    case folder
    case audiobook
    case author
    case narrator
  }

  public let id: String
  public let name: String
  public let kind: Kind
  
  public let durationSeconds: Int64?
  public let currentSeconds: Int64?
  public let isFinished: Bool?
  public let lastPlayedDate: Date?
  public let blurHash: String?
  public let imageAspectRatio: Double?
  public let details: JellyfinAudiobookDetailsData?

  public var isDownloadable: Bool {
    kind == .audiobook
  }

  public var isNavigable: Bool {
    !isDownloadable
  }

  public var displayName: String { name }

  public var placeholderImageName: String {
    switch kind {
    case .audiobook: "waveform"
    case .userView, .folder: "folder"
    case .author: "person"
    case .narrator: "mic"
    }
  }
}

extension JellyfinLibraryItem {
  public init(id: String, name: String, kind: Kind) {
    self.init(
      id: id,
      name: name,
      kind: kind,
      durationSeconds: nil,
      currentSeconds: nil,
      isFinished: false,
      lastPlayedDate: nil,
      blurHash: nil,
      imageAspectRatio: nil,
      details: nil
    )
  }
}

extension JellyfinLibraryItem {
  /// Jellyfin only reports a runtime at the item level once it has probed the file, but the
  /// media source can carry one on its own — and a virtual import is REFUSED without a
  /// runtime, so take it wherever it exists.
  ///
  /// Static and tick-typed rather than inline in the mapper so the resolution can be tested
  /// without a `BaseItemDto`: `BookPlayerTests` declares no JellyfinAPI dependency, so a test
  /// that names one of its types compiles but fails to LINK.
  static func resolveRuntimeSeconds(itemTicks: Int?, mediaSourceTicks: Int?) -> TimeInterval? {
    (itemTicks ?? mediaSourceTicks).map { TimeInterval($0) / 10000000.0 }
  }

  /// The playable file's extension: Jellyfin reports a media source's container, which can be
  /// a comma-separated list of candidates, and falls back to the path's own extension.
  ///
  /// Shared with `JellyfinConnectionService.fetchItemDetails` for the same reason as the
  /// runtime — the two producers of `JellyfinAudiobookDetailsData` must not disagree about
  /// whether an item is importable.
  static func resolveFileExtension(container: String?, filePath: String?) -> String? {
    container?.components(separatedBy: ",").first
      ?? container
      ?? (filePath as NSString?)?.pathExtension
  }

  public init?(apiItem: BaseItemDto) {
    let kind: JellyfinLibraryItem.Kind? = switch apiItem.type {
    case .userView, .collectionFolder: .userView
    case .folder: .folder
    case .audioBook: .audiobook
    default: nil
    }
    
    guard let id = apiItem.id, let kind else {
      return nil
    }
    let name = apiItem.name ?? id
    let blurHash = apiItem.imageBlurHashes?.primary?.first?.value
    
    let artist = apiItem.albumArtist ?? apiItem.artists?.first
    let filePath = apiItem.mediaSources?.first?.path ?? apiItem.path
    let runtimeInSeconds = Self.resolveRuntimeSeconds(
      itemTicks: apiItem.runTimeTicks,
      mediaSourceTicks: apiItem.mediaSources?.first?.runTimeTicks
    )
    let fileExtension = Self.resolveFileExtension(
      container: apiItem.mediaSources?.first?.container,
      filePath: filePath
    )

    var myDetails: JellyfinAudiobookDetailsData? = nil
    if artist != nil || filePath != nil || runtimeInSeconds != nil || fileExtension != nil {
      myDetails = JellyfinAudiobookDetailsData(
        artist: artist,
        filePath: filePath,
        fileSize: apiItem.mediaSources?.first?.size,
        fileExtension: fileExtension,
        overview: apiItem.overview,
        runtimeInSeconds: runtimeInSeconds,
        genres: apiItem.genres,
        tags: apiItem.tags
      )
    }
    
    self.init(
      id: id,
      name: name,
      kind: kind,
      durationSeconds: Int64(runtimeInSeconds ?? 0),
      currentSeconds: Int64((apiItem.userData?.playbackPositionTicks ?? 0) / 10000000),
      isFinished: apiItem.userData?.isPlayed,
      lastPlayedDate: apiItem.userData?.lastPlayedDate,
      blurHash: blurHash,
      imageAspectRatio: apiItem.primaryImageAspectRatio,
      details: myDetails
    )
  }

  /// Create an author item from an AlbumArtists API response
  init?(authorApiItem: BaseItemDto) {
    guard let id = authorApiItem.id else { return nil }
    let name = authorApiItem.name ?? id
    let blurHash = authorApiItem.imageBlurHashes?.primary?.first?.value
    self.init(id: id, name: name, kind: .author, durationSeconds: Int64((authorApiItem.runTimeTicks ?? 0) / 10000000), currentSeconds: Int64((authorApiItem.userData?.playbackPositionTicks ?? 0) / 10000000), isFinished: authorApiItem.userData?.isPlayed,
              lastPlayedDate: authorApiItem.userData?.lastPlayedDate, blurHash: blurHash, imageAspectRatio: authorApiItem.primaryImageAspectRatio, details: nil)
  }

  /// Create a narrator item from a Persons API response
  init?(narratorApiItem: BaseItemDto) {
    guard let id = narratorApiItem.id else { return nil }
    let name = narratorApiItem.name ?? id
    let blurHash = narratorApiItem.imageBlurHashes?.primary?.first?.value
    self.init(id: id, name: name, kind: .narrator, durationSeconds: Int64((narratorApiItem.runTimeTicks ?? 0) / 10000000), currentSeconds: Int64((narratorApiItem.userData?.playbackPositionTicks ?? 0) / 10000000), isFinished: narratorApiItem.userData?.isPlayed,
              lastPlayedDate: narratorApiItem.userData?.lastPlayedDate, blurHash: blurHash, imageAspectRatio: narratorApiItem.primaryImageAspectRatio, details: nil)
  }
}

// MARK: - Virtual import

extension JellyfinLibraryItem {
  /// Builds the virtual-import payload for this item. The file extension and the duration
  /// are REQUIRED and both come from hydration (`VirtualImportPipeline`): callers hydrate
  /// from the server (`fetchItems(ids:)` requests media sources) and SKIP items that have
  /// neither. An item without audio-file metadata has nothing to stream, so the extension
  /// is never guessed; one Jellyfin has not probed has no runtime, and importing it with a
  /// 0 duration yields a row that can never play.
  @MainActor
  public func asVirtualImportResource(
    fileExtension: String,
    duration: TimeInterval,
    detailsOverride: JellyfinAudiobookDetailsData?,
    connectionService: JellyfinConnectionService,
    artworkSize: CGSize
  ) -> SimpleExternalResource {
    let resolvedDetails = detailsOverride ?? details
    let libraryItem = SimpleLibraryItem(
      title: name,
      details: resolvedDetails?.artist ?? "voiceover_unknown_author".localized,
      speed: 1,
      currentTime: Double(currentSeconds ?? 0),
      duration: duration,
      /// The duration half of the old guard is now the pipeline's precondition, so the
      /// division is safe on any item that reaches here.
      percentCompleted: (currentSeconds ?? 0) > 0
        ? Double(currentSeconds!) / duration * 100
        : 0,
      isFinished: isFinished ?? false,
      relativePath: "",
      remoteURL: nil,
      artworkURL: try? connectionService.createItemImageURL(self, size: artworkSize),
      orderRank: 0,
      parentFolder: nil,
      originalFileName: "\(name).\(fileExtension)",
      lastPlayDate: lastPlayedDate,
      type: .book,
      uuid: UUID().uuidString
    )

    return SimpleExternalResource(
      id: abs(UUID().hashValue),  // unique per element — a shared timestamp collides Identifiable ids within a batch
      providerName: ExternalResource.ProviderName.jellyfin.rawValue,
      providerId: id,
      syncStatus: ExternalResource.SyncStatus.stream.rawValue,
      lastSyncedAt: nil,
      hostId: connectionService.connection?.stableHostId,
      libraryItem: libraryItem
    )
  }
}
