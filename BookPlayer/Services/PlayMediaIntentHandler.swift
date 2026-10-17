//
//  PlayMediaIntentHandler.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import Intents

/// Plays what the system's playback suggestions, Siri and Shortcuts ask for. Handled in the app
/// (`application(_:handlerFor:)`), not in the Intents extension: playback runs here, and a cold
/// launch waits for the core services, as the App Intents do.
final class PlayMediaIntentHandler: NSObject, INPlayMediaIntentHandling {
  /// Matches compared to find the most recently played book: an author's name is on every part of
  /// a bound book
  static let searchLimit = 50

  func resolveMediaItems(for intent: INPlayMediaIntent) async -> [INPlayMediaMediaItemResolutionResult] {
    /// A suggestion or a Shortcut already names the book
    if let mediaItems = intent.mediaItems, !mediaItems.isEmpty {
      return INPlayMediaMediaItemResolutionResult.successes(with: mediaItems)
    }
    if let container = intent.mediaContainer {
      return INPlayMediaMediaItemResolutionResult.successes(with: [container])
    }

    let query = intent.mediaSearch?.mediaName ?? intent.mediaSearch?.artistName
    guard let book = await Self.findBook(matching: query) else {
      return [INPlayMediaMediaItemResolutionResult.unsupported()]
    }

    return INPlayMediaMediaItemResolutionResult.successes(with: [book])
  }

  func handle(intent: INPlayMediaIntent) async -> INPlayMediaIntentResponse {
    let identifier = (intent.mediaItems?.first ?? intent.mediaContainer)?.identifier
    let code = await Self.play(identifier: identifier)

    return INPlayMediaIntentResponse(code: code, userActivity: nil)
  }

  @MainActor
  private static func findBook(matching query: String?) async -> INMediaItem? {
    guard let libraryService = try? await AppServices.shared.awaitCoreServices().libraryService else {
      return nil
    }

    /// The parts of one bound book share a parent: look it up once
    var boundBooks = [String: SimpleLibraryItem?]()

    guard
      let item = book(
        matching: query,
        search: { libraryService.searchAllBooks(query: $0, limit: searchLimit, offset: nil) ?? [] },
        lastPlayed: { libraryService.getLastPlayedItems(limit: 1)?.first },
        boundBook: { found in
          guard let parentPath = found.parentFolder else { return nil }
          if let boundBook = boundBooks[parentPath] { return boundBook }

          let boundBook =
            isBoundBook(at: parentPath, in: libraryService)
            ? libraryService.getSimpleItem(with: parentPath)
            : nil
          boundBooks[parentPath] = boundBook
          return boundBook
        }
      )
    else { return nil }

    return MediaSuggestionsController.mediaItem(
      identifier: item.stableIdentifier,
      title: item.title,
      author: MediaSuggestionsController.author(
        of: item,
        boundBookAuthor: { libraryService.fetchContents(at: $0, limit: 1, offset: nil)?.first?.details }
      ),
      artwork: nil
    )
  }

  /// The book a request names: the most recently played one whose title or author has what was
  /// said, or with nothing said, the last one played. A part of a bound book stands for the bound
  /// book, as in the Search tab
  static func book(
    matching query: String?,
    search: (String) -> [SimpleLibraryItem],
    lastPlayed: () -> SimpleLibraryItem?,
    boundBook: (SimpleLibraryItem) -> SimpleLibraryItem?
  ) -> SimpleLibraryItem? {
    guard let query, !query.isEmpty else {
      return lastPlayed().map { boundBook($0) ?? $0 }
    }

    /// Ranked once mapped: a bound book's parts have no play date of their own
    var mostRecent: SimpleLibraryItem?
    for match in search(query) {
      let book = boundBook(match) ?? match
      if mostRecent == nil || (book.lastPlayDate ?? .distantPast) > (mostRecent?.lastPlayDate ?? .distantPast) {
        mostRecent = book
      }
    }

    return mostRecent
  }

  @MainActor
  private static func play(identifier: String?) async -> INPlayMediaIntentResponseCode {
    guard let coreServices = try? await AppServices.shared.awaitCoreServices() else { return .failure }
    let libraryService = coreServices.libraryService

    let relativePath: String?
    if let identifier {
      relativePath = Self.relativePath(
        for: identifier,
        uuidLookup: { libraryService.getRelativePath(forUuid: $0) },
        isBook: { libraryService.getSimpleItem(with: $0).map { $0.type != .folder } ?? false },
        boundBookPath: { boundBookPath(of: $0, in: libraryService) }
      )
      /// Gone since it was suggested, or no longer a book (a bound book made a plain folder): stop
      /// suggesting it. A book since bound plays as the bound book, which playing donates
      if relativePath.flatMap({ libraryService.getSimpleItem(with: $0)?.stableIdentifier }) != identifier {
        try? await INInteraction.delete(with: identifier)
      }
    } else {
      /// The "Resume last played book" Shortcut names no book
      relativePath = libraryService.getLastPlayedItems(limit: 1)?.first?.relativePath
    }

    guard let relativePath else { return .failure }

    do {
      try await AppServices.shared.loadAndKeepAlive(
        relativePath: relativePath,
        playerLoaderService: coreServices.playerLoaderService
      )
      return .success
    } catch {
      return .failure
    }
  }

  /// Where the book an intent names is now, if it's still a book. Ids are uuids, or paths for items
  /// without a real uuid. A book since bound into a bound book plays as the bound book
  static func relativePath(
    for identifier: String,
    uuidLookup: (String) -> String?,
    isBook: (String) -> Bool,
    boundBookPath: (String) -> String?
  ) -> String? {
    let relativePath = uuidLookup(identifier) ?? identifier
    guard isBook(relativePath) else { return nil }

    return boundBookPath(relativePath) ?? relativePath
  }

  /// The bound book the book at this path is a part of, if any
  @MainActor
  static func boundBookPath(of relativePath: String, in libraryService: LibraryServiceProtocol) -> String? {
    guard
      let parentPath = libraryService.getSimpleItem(with: relativePath)?.parentFolder,
      isBoundBook(at: parentPath, in: libraryService)
    else { return nil }

    return parentPath
  }

  @MainActor
  private static func isBoundBook(at relativePath: String, in libraryService: LibraryServiceProtocol) -> Bool {
    libraryService.getItemProperty("type", relativePath: relativePath) as? Int16 == SimpleItemType.bound.rawValue
  }
}
