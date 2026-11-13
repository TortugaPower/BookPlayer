//
//  SharePlayService.swift
//  BookPlayer
//
//  Created by dawsonamf on 6/28/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import BookPlayerKit
import Combine
import Foundation
import GroupActivities
import UIKit

/// Why the local device couldn't join playback for a shared book.
enum SharePlayJoinFailure: Error {
  /// No matching book in the local library.
  case bookNotFound
  /// A matching book exists but its file couldn't be loaded (e.g. not downloaded).
  case loadFailed
}

@MainActor
final class SharePlayService: ObservableObject, BPLogger {
  /// Whether this device holds a session, joined or still loading its book: either can be left
  @Published private(set) var isInSession = false

  private let playerManager: PlayerManager
  private let matcher: BookLibraryMatcher
  private let groupStateObserver = GroupStateObserver()

  private var currentSession: GroupSession<AudioBookActivity>?
  /// The local library item the current session is coordinated against; nil while a join
  /// loads it, which keeps the current-item observer quiet while this service swaps books.
  private var coordinatedRelativePath: String?
  private var sessionsTask: Task<Void, Never>?
  /// The one join waiting on its book. A newer join, or the session ending, cancels it.
  private var joinTask: Task<Void, Never>?
  private var sessionObservers = Set<AnyCancellable>()
  private var currentItemObserver: AnyCancellable?

  init(
    playerManager: PlayerManager,
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol
  ) {
    self.playerManager = playerManager
    self.matcher = BookLibraryMatcher(
      libraryService: libraryService,
      playbackService: playbackService
    )

    sessionsTask = Task { [weak self] in
      for await session in AudioBookActivity.sessions() {
        self?.configure(session)
      }
    }

    // if this device stops playing the coordinated book (switch, stop, delete), exit the session
    // instead of silently coordinating other content. The book loaded now decides, not the one
    // delivered: a reload of the same book publishes nil on its way
    currentItemObserver = playerManager.currentItemPublisher()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self,
          let coordinatedRelativePath = self.coordinatedRelativePath,
          self.playerManager.currentItem?.relativePath != coordinatedRelativePath
        else { return }

        self.leaveSession()
      }
  }

  deinit {
    sessionsTask?.cancel()
  }

  // MARK: - Starting and leaving

  func makeActivity(for item: PlayableItem) -> AudioBookActivity {
    AudioBookActivity(
      bookFingerprint: BookFingerprint(from: item),
      bookTitle: item.title,
      bookAuthor: BookFingerprint.normalizeAuthor(item.author).isEmpty ? "" : item.author
    )
  }

  /// Shares `item` with the FaceTime call or Messages conversation under way. False when
  /// there's none to activate into: offer the system sharing sheet instead.
  func startSession(for item: PlayableItem) async -> Bool {
    guard groupStateObserver.isEligibleForGroupSession else { return false }

    let activity = makeActivity(for: item)

    if case .activationPreferred = await activity.prepareForActivation() {
      do {
        _ = try await activity.activate()
      } catch {
        Self.logger.error("Failed to activate the activity: \(error)")
      }
    }

    return true
  }

  func leaveSession() {
    currentSession?.leave()
    handleSessionEnded()
  }

  func endSession() {
    currentSession?.end()
    handleSessionEnded()
  }

  // MARK: - Session handling

  private func configure(_ session: GroupSession<AudioBookActivity>) {
    // a new session supersedes the previous one, which is left before its coordination
    // goes: the player's own speed coming back is no business of that group's
    if let previousSession = currentSession, previousSession !== session {
      if case .invalidated = previousSession.state {} else {
        previousSession.leave()
      }
      playerManager.setPlaybackCoordination(nil)
    }

    sessionObservers.removeAll()
    currentSession = session
    isInSession = true

    observe(session)

    join(session.activity, in: session)
  }

  /// Hands the session to the player once the activity's book is loaded locally.
  /// Re-runs when the group switches books mid-session
  private func join(_ activity: AudioBookActivity, in session: GroupSession<AudioBookActivity>) {
    loadLocalCopy(of: activity.bookFingerprint) { [weak self] result in
      guard let self else { return }

      switch result {
      case .success(let relativePath):
        self.coordinate(relativePath, as: activity.bookFingerprint.identifier) {
          $0.coordinateWithSession(session)
        }

        if case .waiting = session.state {
          session.join()
        }
      case .failure(let reason):
        // notify, then leave so the group isn't waiting on a participant that will never join
        self.presentJoinFailure(reason, for: activity)
        self.leaveSession()
      }
    }
  }

  /// Attaches the session to the player for the book at `relativePath`, which reports
  /// `contentIdentifier` to the group; any other book leaves the session
  func coordinate(
    _ relativePath: String,
    as contentIdentifier: String,
    with coordinateSession: @escaping (AVPlayerPlaybackCoordinator) -> Void
  ) {
    coordinatedRelativePath = relativePath
    playerManager.setPlaybackCoordination(SharePlayPlaybackCoordination(
      contentIdentifier: contentIdentifier,
      relativePath: relativePath,
      currentItem: { [weak playerManager] in playerManager?.currentItem },
      coordinateSession: coordinateSession
    ))
  }

  /// Matches `fingerprint`'s book locally and loads it if needed, then hands `completion` its
  /// path once it can play. One at a time: a newer call, or the session ending, drops an
  /// earlier one's completion
  func loadLocalCopy(
    of fingerprint: BookFingerprint,
    completion: @escaping (Result<String, SharePlayJoinFailure>) -> Void
  ) {
    joinTask?.cancel()
    // a join starts from an uncoordinated player: the book it loads seeks to its saved position,
    // and the current-item observer stays quiet while this service swaps books
    coordinatedRelativePath = nil
    playerManager.setPlaybackCoordination(nil)

    let book: PlayableItem
    // typical for the session initiator
    let isAlreadyLoaded: Bool

    if let current = playerManager.currentItem,
      matcher.matches(BookFingerprint(from: current), fingerprint)
    {
      book = current
      isAlreadyLoaded = true
    } else if let match = matcher.find(matching: fingerprint) {
      book = match
      isAlreadyLoaded = false
      playerManager.load(match, intent: .idle)
    } else {
      Self.logger.info("No local match for the shared book")
      completion(.failure(.bookNotFound))
      return
    }

    // wait for the file itself, not its load being under way: the seek to the saved position
    // must land before the session reaches the player, or it goes out to the group
    joinTask = Task { [playerManager] in
      var canPlay = await playerManager.awaitItemLoad()

      // the loaded book's file can be out of the player (a failed load, a media-services reset):
      // its next play would load it, and seek, with the session attached
      if !canPlay, isAlreadyLoaded, !Task.isCancelled, playerManager.currentItem === book {
        playerManager.load(book, intent: .idle)
        canPlay = await playerManager.awaitItemLoad()
      }

      guard !Task.isCancelled else { return }

      if canPlay, playerManager.currentItem?.relativePath == book.relativePath {
        completion(.success(book.relativePath))
      } else {
        completion(.failure(.loadFailed))
      }
    }
  }

  private func observe(_ session: GroupSession<AudioBookActivity>) {
    session.$state
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        guard let self, self.currentSession === session else { return }

        if case .invalidated = state {
          self.handleSessionEnded()
        }
      }
      .store(in: &sessionObservers)

    // participants can swap the session's book in place; re-run the match for the new book
    session.$activity
      .receive(on: DispatchQueue.main)
      .removeDuplicates { $0.bookFingerprint == $1.bookFingerprint }
      .dropFirst()
      .sink { [weak self] activity in
        guard let self, self.currentSession === session else { return }

        self.join(activity, in: session)
      }
      .store(in: &sessionObservers)
  }

  private func handleSessionEnded() {
    joinTask?.cancel()
    playerManager.setPlaybackCoordination(nil)
    currentSession = nil
    coordinatedRelativePath = nil
    sessionObservers.removeAll()
    isInSession = false
  }

  private func presentJoinFailure(_ reason: SharePlayJoinFailure, for activity: AudioBookActivity) {
    let author = activity.bookAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
    let subject =
      author.isEmpty
      ? String(format: "shareplay_book_subject_no_author_title".localized, activity.bookTitle)
      : String(format: "shareplay_book_subject_title".localized, activity.bookTitle, author)

    let message: String
    switch reason {
    case .bookNotFound:
      message = String(format: "shareplay_book_not_found_description".localized, subject)
    case .loadFailed:
      message = String(format: "shareplay_book_load_failed_description".localized, subject)
    }

    WindowHelper.activeWindow?.rootViewController?
      .getTopVisibleViewController()?
      .showAlert("shareplay_title".localized, message: message)
  }
}
