//
//  MediaSuggestionsController.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
import ImageIO
import Intents
import UIKit

/// Feeds the system's playback suggestions, which the Lock Screen, Control Center and the Home
/// app show while nothing is playing. They come only from SiriKit media: an `INPlayMediaIntent`
/// donation each time a book starts, the recent unfinished books as upcoming media, and the media
/// user context (App Intents has no equivalent). `PlayMediaIntentHandler` plays what they name.
///
/// Every intent names its book as the container only: the intent definition's supported
/// combination with `mediaContainer` alone is what opts the app into these suggestions.
@MainActor
final class MediaSuggestionsController {
  struct Dependencies {
    /// Played items, most recent first
    var recentItems: (_ limit: Int) -> [SimpleLibraryItem]
    /// Books in the library, a bound book counting once
    var bookCount: () -> Int
    /// A bound book's author: its first part's
    var boundBookAuthor: (_ relativePath: String) -> String?
    /// PRO or LITE
    var hasSyncEnabled: () -> Bool
    /// Cached artwork for the first of these paths that has it, sized for a suggestion
    var artworkData: (_ relativePaths: [String]) async -> Data?
    var donate: (INInteraction) -> Void
    var deleteDonations: (_ groupIdentifier: String) -> Void
    var setSuggestedIntents: ([INPlayMediaIntent]) -> Void
    var setUserContext: (INMediaUserContext) -> Void
    /// The book that just started playing (`.bookPlayed`)
    var bookPlayed: AnyPublisher<PlayableItem, Never>
    /// `LibraryService.metadataUpdatePublisher`
    var metadataUpdates: AnyPublisher<[String: Any], Never>
    /// `ArtworkService.artworkUpdatePublisher`: a cover was added or replaced
    var artworkUpdates: AnyPublisher<String, Never>
  }

  /// How many unfinished books are offered as upcoming media
  static let upcomingLimit = 5
  /// Played items read to find them: finished ones are skipped
  static let recentItemsLimit = 20

  private var dependencies: Dependencies?
  /// A resume of the same book isn't a new donation
  private var lastDonatedIdentifier: String?
  private var donationTask: Task<Void, Never>?
  private var refreshTask: Task<Void, Never>?
  /// Covers shrunk this launch, by book id: a refresh rebuilds every intent, mostly with the same
  /// covers. Only the listed books' are kept
  private var artwork = [String: Data]()
  /// Bumped when a cover changes, so a cover read before the change isn't kept
  private var artworkGeneration = 0
  private var disposeBag = Set<AnyCancellable>()

  /// The latest donation and the upcoming list being built, for tests to await
  var pendingDonation: Task<Void, Never>? { donationTask }
  var pendingRefresh: Task<Void, Never>? { refreshTask }

  func setup(dependencies: Dependencies) {
    self.dependencies = dependencies

    publishUserContext()
    refreshUpcoming()

    dependencies.bookPlayed
      .sink { [weak self] item in
        self?.bookStarted(item)
      }
      .store(in: &disposeBag)

    dependencies.metadataUpdates
      .receive(on: DispatchQueue.main)
      .sink { [weak self] update in
        self?.handleMetadataUpdate(update)
      }
      .store(in: &disposeBag)

    /// Rare: the covers asked for next are shrunk again, five at most
    dependencies.artworkUpdates
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.artwork.removeAll()
        self?.artworkGeneration += 1
      }
      .store(in: &disposeBag)
  }

  // MARK: - Donations

  private func bookStarted(_ item: PlayableItem) {
    guard
      let dependencies,
      item.id != lastDonatedIdentifier
    else { return }

    lastDonatedIdentifier = item.id

    let identifier = item.id
    let title = item.title
    let author = item.author
    let relativePath = item.relativePath
    let partPath = item.currentChapter.relativePath

    donationTask?.cancel()
    donationTask = Task { [weak self] in
      var artwork = await self?.artworkData(for: identifier, relativePath: relativePath)
      /// A bound book's folder may have no cover cached yet: the playing part's stands in, not
      /// kept, so the folder's own replaces it once cached
      if artwork == nil, partPath != relativePath {
        artwork = await dependencies.artworkData([partPath])
      }
      /// Another book started while this one's cover was read: donated now, this one would look
      /// like the more recent play
      guard !Task.isCancelled else { return }

      let intent = Self.playIntent(
        for: Self.mediaItem(identifier: identifier, title: title, author: author, artwork: artwork)
      )
      let interaction = INInteraction(
        intent: intent,
        response: INPlayMediaIntentResponse(code: .success, userActivity: nil)
      )
      interaction.groupIdentifier = identifier
      dependencies.donate(interaction)

      self?.refreshUpcoming()
    }
  }

  /// A finished book is no longer worth suggesting; one marked unfinished can be again
  private func handleMetadataUpdate(_ update: [String: Any]) {
    guard
      let dependencies,
      let isFinished = update["isFinished"] as? Bool,
      let relativePath = update["relativePath"] as? String
    else { return }

    if isFinished {
      let identifier = Self.identifier(uuid: update["uuid"] as? String ?? "", relativePath: relativePath)
      dependencies.deleteDonations(identifier)
      /// Listening to it again is a new start
      if lastDonatedIdentifier == identifier {
        lastDonatedIdentifier = nil
      }
    }

    refreshUpcoming()
  }

  // MARK: - Upcoming media

  /// Rebuilds the whole list; a newer refresh replaces one still building
  private func refreshUpcoming() {
    guard let dependencies else { return }

    refreshTask?.cancel()
    refreshTask = Task { [weak self] in
      /// Marking a folder finished asks for one refresh per book: only the last one runs
      guard !Task.isCancelled else { return }

      let items = dependencies.recentItems(Self.recentItemsLimit)
        .filter { !$0.isFinished }
        .prefix(Self.upcomingLimit)

      var intents = [INPlayMediaIntent]()
      for item in items {
        let artwork = await self?.artworkData(for: item.stableIdentifier, relativePath: item.relativePath)
        guard !Task.isCancelled else { return }

        intents.append(
          Self.playIntent(
            for: Self.mediaItem(
              identifier: item.stableIdentifier,
              title: item.title,
              author: Self.author(of: item, boundBookAuthor: dependencies.boundBookAuthor),
              artwork: artwork
            )
          )
        )
      }

      guard !Task.isCancelled, let self else { return }
      let listed = Set(items.map(\.stableIdentifier))
      self.artwork = self.artwork.filter { listed.contains($0.key) }
      dependencies.setSuggestedIntents(intents)
    }
  }

  /// A book's own cover, shrunk once per launch. None isn't kept: a cover can be cached without
  /// `artworkUpdates` (read from the file when the library shows it)
  private func artworkData(for identifier: String, relativePath: String) async -> Data? {
    if let data = artwork[identifier] { return data }
    guard let dependencies else { return nil }

    let generation = artworkGeneration
    let data = await dependencies.artworkData([relativePath])
    if let data, generation == artworkGeneration {
      artwork[identifier] = data
    }

    return data
  }

  // MARK: - User context

  /// Set once per launch, as Apple asks. Only a sync tier counts as a subscription; anyone else
  /// stays `.unknown`, never `.notSubscribed`: every user can play their whole library
  private func publishUserContext() {
    guard let dependencies else { return }

    let context = INMediaUserContext()
    context.numberOfLibraryItems = dependencies.bookCount()
    if dependencies.hasSyncEnabled() {
      context.subscriptionStatus = .subscribed
    }
    dependencies.setUserContext(context)
  }

  // MARK: - Intents

  /// The id donations and suggestions name a book by: its uuid, or its path when it has no real
  /// one (the same rule as `PlayableItem.id`)
  static func identifier(uuid: String, relativePath: String) -> String {
    Constants.isRealUuid(uuid) ? uuid : relativePath
  }

  /// A bound book's own details are its file count: its author is its first part's, as when it plays
  /// (`PlaybackService`)
  static func author(of item: SimpleLibraryItem, boundBookAuthor: (String) -> String?) -> String {
    item.type == .bound ? boundBookAuthor(item.relativePath) ?? "" : item.details
  }

  static func mediaItem(identifier: String, title: String, author: String, artwork: Data?) -> INMediaItem {
    INMediaItem(
      identifier: identifier,
      title: title,
      type: .audioBook,
      artwork: artwork.map { INImage(imageData: $0) },
      artist: author.isEmpty ? nil : author
    )
  }

  static func playIntent(for book: INMediaItem) -> INPlayMediaIntent {
    INPlayMediaIntent(
      mediaItems: nil,
      mediaContainer: book,
      playShuffled: nil,
      playbackRepeatMode: .unknown,
      resumePlayback: nil,
      playbackQueueLocation: .unknown,
      playbackSpeed: nil,
      mediaSearch: nil
    )
  }

  // MARK: - Artwork

  /// Side of the artwork a donation carries: suggestions show it small
  nonisolated static let artworkSide: CGFloat = 256

  /// The first cached cover among `relativePaths`, shrunk to `artworkSide`. `@concurrent`: the decode
  /// runs off the main actor whatever the build's concurrency settings
  @concurrent nonisolated static func cachedArtworkData(for relativePaths: [String]) async -> Data? {
    for relativePath in relativePaths where ArtworkService.isCached(relativePath: relativePath) {
      if let data = thumbnailData(at: ArtworkService.getCachedImageURL(for: relativePath)) {
        return data
      }
    }

    return nil
  }

  /// The image at `url` decoded straight to `artworkSide` with ImageIO, as the widgets do: the full
  /// cover (often thousands of pixels) is never decoded. Never larger than the original
  nonisolated static func thumbnailData(at url: URL) -> Data? {
    guard
      let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
    else { return nil }

    let options: [CFString: Any] = [
      /// Not a small thumbnail the file may embed
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: artworkSide,
    ]

    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

    return UIImage(cgImage: image).jpegData(compressionQuality: 0.8)
  }
}
