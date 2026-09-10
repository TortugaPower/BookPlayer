//
//  ExternalProgressService.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation

/// Pulls the position a book's media servers report, so playback can offer to resume where
/// another device left off.
///
/// This is the inbound half of media-server progress sync. The outbound half already lives in
/// a service — `libraryService.progressUpdatePublisher` feeds `SyncService.scheduleMetadataUpdate`
/// and the `externalUpdate` queue — while the pull used to live on `ItemListViewModel`, reached
/// through a delegate that exists for an unrelated question. That made a UI object's identity
/// decide whether the feature ran at all: CarPlay claims the same delegate slot and answered
/// with an empty implementation, so a car-only session silently never pulled.
///
/// Nothing here is entitlement-gated, matching the push: `.externalUpdate` runs on every tier
/// because it talks to the user's OWN server, and gating only the pull would make the two
/// directions disagree.
public final class ExternalProgressService {
  /// A remote position worth offering the user, published rather than written into UI state so
  /// both presentations — the SwiftUI alert and CarPlay's own — can consume the one decision.
  public let promptablePositionPublisher = PassthroughSubject<ExternalPlaybackProgress, Never>()

  private var libraryService: LibraryServiceProtocol!
  private var providers: [ExternalResource.ProviderName: ExternalProgressProviding] = [:]

  /// Guards the single in-flight refresh and the uuid it was started for. Non-isolated so the
  /// concurrent fan-out below doesn't have to hop to an actor to read them.
  private let stateLock = NSLock()
  private var refreshTask: Task<Void, Never>?
  private var requestedUuid: String?
  private var disposeBag = Set<AnyCancellable>()

  public init() {}

  public func setup(
    libraryService: LibraryServiceProtocol,
    providers: [ExternalResource.ProviderName: ExternalProgressProviding] = [
      .jellyfin: JellyfinProgressProvider(),
      .audiobookshelf: AudiobookShelfProgressProvider(),
    ]
  ) {
    self.libraryService = libraryService
    self.providers = providers

    bindObservers()
  }

  /// Self-subscribed rather than called by the player, so nothing about which UI is attached
  /// can decide whether a refresh happens — the point of moving this off a view model.
  /// `.bookPlayed` is posted by PlayerManager for every playback start, phone or CarPlay.
  private func bindObservers() {
    NotificationCenter.default.publisher(for: .bookPlayed)
      .compactMap { $0.userInfo?["book"] as? PlayableItem }
      .sink { [weak self] item in
        self?.refreshProgress(for: item)
      }
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .logout)
      .sink { [weak self] _ in
        self?.teardown()
      }
      .store(in: &disposeBag)
  }

  /// Ask every media server this item is linked to where the user is, and publish the answer
  /// if it is far enough ahead of the local position to be worth a prompt.
  ///
  /// Replaces any refresh already running: only the item that is playing NOW can produce a
  /// prompt. The previous design keyed tasks by uuid, so a slow answer for a book the user had
  /// already moved on from could still raise a prompt carrying that book's position — and the
  /// alert's "resume" then seeks whatever is playing to a timestamp from another book.
  public func refreshProgress(for item: PlayableItem) {
    let uuid = item.uuid
    let localTime = item.currentTime
    let localDate = item.lastPlayDate

    stateLock.lock()
    refreshTask?.cancel()
    requestedUuid = uuid
    stateLock.unlock()

    let task = Task { [weak self] in
      guard let self else { return }

      let resources = (self.libraryService.findResources(for: uuid) ?? []).mediaServerResources
      // No media server for this book: nothing to ask, and in particular no keychain read.
      guard !resources.isEmpty else { return }

      let candidates = await self.fetchConcurrently(for: resources)

      guard
        !Task.isCancelled,
        self.isStillRequested(uuid),
        let position = Self.promptablePosition(
          localTime: localTime,
          localDate: localDate,
          candidates: candidates
        )
      else { return }

      self.promptablePositionPublisher.send(position)
    }

    stateLock.lock()
    refreshTask = task
    stateLock.unlock()
  }

  /// Refresh the positions of items already on screen, so a list shows what the user's other
  /// devices did without waiting for them to open each book.
  ///
  /// Every provider is asked in parallel and each folds its own answers in, so AudiobookShelf
  /// items refresh alongside Jellyfin ones — they never did before, because the ingest was
  /// typed to a Jellyfin item and the caller collected only Jellyfin resources.
  public func refreshItems(_ items: [SimpleLibraryItem]) async {
    let resources = items.flatMap { $0.externalResources?.mediaServerResources ?? [] }
    guard !resources.isEmpty else { return }

    let byProvider = Dictionary(grouping: resources) { $0.providerName }

    await withTaskGroup(of: (String, [String: ExternalPlaybackProgress]).self) { group in
      for (providerName, providerResources) in byProvider {
        guard
          let name = ExternalResource.ProviderName(rawValue: providerName),
          let provider = providers[name]
        else { continue }

        group.addTask {
          (providerName, (try? await provider.progress(forBatch: providerResources)) ?? [:])
        }
      }

      for await (providerName, progress) in group where !progress.isEmpty {
        await libraryService.handleSyncFromExternalResource(
          providerName: providerName,
          progressByProviderId: progress
        )
      }
    }
  }

  /// Cancels any refresh in flight. Called on logout, the same lifecycle hook SyncService uses.
  public func teardown() {
    stateLock.lock()
    refreshTask?.cancel()
    refreshTask = nil
    requestedUuid = nil
    stateLock.unlock()
  }

  /// One task group so a slow or unreachable server delays nobody, and a thrown error takes
  /// only its own provider out of the running.
  private func fetchConcurrently(
    for resources: [SimpleExternalResource]
  ) async -> [ExternalPlaybackProgress] {
    await withTaskGroup(of: ExternalPlaybackProgress?.self) { group in
      for resource in resources {
        guard
          let name = ExternalResource.ProviderName(rawValue: resource.providerName),
          let provider = providers[name]
        else { continue }

        group.addTask {
          try? await provider.progress(for: resource)
        }
      }

      var candidates: [ExternalPlaybackProgress] = []
      for await candidate in group {
        if let candidate {
          candidates.append(candidate)
        }
      }
      return candidates
    }
  }

  private func isStillRequested(_ uuid: String) -> Bool {
    stateLock.lock()
    defer { stateLock.unlock() }
    return requestedUuid == uuid
  }

  /// The position worth prompting for, or nil when the servers have nothing newer to offer.
  ///
  /// Two steps. A candidate qualifies only if it is ahead of the local state by more than
  /// `threshold` — either a newer play date or a farther position — which keeps the prompt
  /// from firing on the rounding drift of a book the user is actively listening to. Among the
  /// qualifiers the NEWEST date wins, the same strictly-newer rule
  /// `SyncService.handleSyncedLastPlayed` and `handleSyncFromExternalResource` already use for
  /// our own cloud, with position breaking ties for servers that report no date.
  static func promptablePosition(
    localTime: TimeInterval,
    localDate: Date?,
    candidates: [ExternalPlaybackProgress],
    threshold: TimeInterval = 15
  ) -> ExternalPlaybackProgress? {
    let localDate = localDate ?? .distantPast

    return candidates
      .filter { candidate in
        let isDateNewer = (candidate.lastPlayedDate ?? .distantPast) > localDate.addingTimeInterval(threshold)
        let isPositionFarther = candidate.currentTime > localTime + threshold

        return isDateNewer || isPositionFarther
      }
      .max {
        ($0.lastPlayedDate ?? .distantPast, $0.currentTime) < ($1.lastPlayedDate ?? .distantPast, $1.currentTime)
      }
  }
}
