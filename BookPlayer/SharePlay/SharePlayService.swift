//
//  SharePlayService.swift
//  BookPlayer
//
//  Created by dawsonamf on 6/28/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
import GroupActivities

/// Why the local device couldn't join playback for a shared book.
enum SharePlayJoinFailure {
  /// No matching book in the local library.
  case bookNotFound
  /// A matching book exists but its file couldn't be loaded (e.g. not downloaded).
  case loadFailed
}

@MainActor
final class SharePlayService: BPLogger {
  private let playerManager: SharePlayCoordinating
  private let matcher: BookLibraryMatcher
  private let playerLoaderService: PlayerLoaderService

  var onSessionStateChange: ((Bool) -> Void)?
  var onParticipantCountChange: ((Int) -> Void)?
  var onJoinFailure: ((SharePlayJoinFailure, AudioBookActivity) -> Void)?

  private var currentSession: GroupSession<AudioBookActivity>?
  /// The local library item the current session is coordinated against.
  private var coordinatedRelativePath: String?
  /// Suppresses the current-item observer while this service itself swaps books.
  private var isReconfiguring = false
  private var sessionsTask: Task<Void, Never>?
  private var sessionObservers = Set<AnyCancellable>()

  init(
    playerManager: SharePlayCoordinating,
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    playerLoaderService: PlayerLoaderService
  ) {
    self.playerManager = playerManager
    self.playerLoaderService = playerLoaderService
    self.matcher = BookLibraryMatcher(
      libraryService: libraryService,
      playbackService: playbackService
    )
  }

  deinit {
    sessionsTask?.cancel()
  }

  func startListening() {
    guard sessionsTask == nil else { return }

    sessionsTask = Task { [weak self] in
      for await session in AudioBookActivity.sessions() {
        await self?.configure(session)
      }
    }
  }

  func leaveCurrentSession() {
    currentSession?.leave()
    handleSessionEnded()
  }

  func endCurrentSession() {
    currentSession?.end()
    handleSessionEnded()
  }

  // MARK: - Session handling

  private func configure(_ session: GroupSession<AudioBookActivity>) async {
    // a new session supersedes the previous one
    if let previousSession = currentSession, previousSession !== session {
      playerManager.stopCoordinatingPlayback()
      if case .invalidated = previousSession.state {} else {
        previousSession.leave()
      }
    }

    teardownSessionObservers()
    currentSession = session
    coordinatedRelativePath = nil

    observe(session)

    await joinPlayback(of: session.activity, in: session)
  }

  /// Matches the activity's book locally, loads it if needed, and hands the session
  /// to the playback coordinator. Re-runs when the group switches books mid-session
  private func joinPlayback(of activity: AudioBookActivity, in session: GroupSession<AudioBookActivity>) async {
    let fingerprint = activity.bookFingerprint

    // fast path: the book is already loaded (typical for the session initiator)
    if let current = playerManager.currentItem,
      matcher.matches(BookFingerprint(from: current), fingerprint)
    {
      startCoordinating(session, relativePath: current.relativePath)
      return
    }

    guard let match = matcher.find(matching: fingerprint) else {
      Self.logger.info("SharePlay: no local match for shared book")
      abandon(session, reason: .bookNotFound, activity: activity)
      return
    }

    isReconfiguring = true
    defer { isReconfiguring = false }

    // `loadPlayer` returns before the item is attached and the saved position
    // restored; wait for the next `.bookReady` so both happen while the player
    // is still uncoordinated and doesn't broadcast its old position to the group
    let loadSignal = nextBookReadySignal()

    do {
      try await playerLoaderService.loadPlayer(
        match.relativePath,
        intent: .idle,
        recordAsLastBook: false
      )
    } catch {
      loadSignal.cancel()
      Self.logger.error("SharePlay: failed to load matched book: \(error)")
      guard currentSession === session else { return }
      abandon(session, reason: .loadFailed, activity: activity)
      return
    }

    let loaded = await loadSignal.value

    // the session can be invalidated while the book is loading
    guard currentSession === session else { return }

    guard loaded, playerManager.currentItem?.relativePath == match.relativePath else {
      abandon(session, reason: .loadFailed, activity: activity)
      return
    }

    startCoordinating(session, relativePath: match.relativePath)
  }

  private func startCoordinating(_ session: GroupSession<AudioBookActivity>, relativePath: String) {
    coordinatedRelativePath = relativePath
    playerManager.coordinatePlayback(with: session, for: relativePath)

    if case .waiting = session.state {
      session.join()
    }
  }

  /// Notify, then leave so the group isn't waiting on a participant that will never join
  private func abandon(
    _ session: GroupSession<AudioBookActivity>,
    reason: SharePlayJoinFailure,
    activity: AudioBookActivity
  ) {
    onJoinFailure?(reason, activity)

    if case .invalidated = session.state {} else {
      session.leave()
    }

    if currentSession === session {
      handleSessionEnded()
    }
  }

  private func observe(_ session: GroupSession<AudioBookActivity>) {
    session.$state
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        self?.handle(state: state, for: session)
      }
      .store(in: &sessionObservers)

    session.$activeParticipants
      .receive(on: DispatchQueue.main)
      .sink { [weak self] participants in
        self?.onParticipantCountChange?(participants.count)
      }
      .store(in: &sessionObservers)

    // participants can swap the session's book in place; re-run the match for the new book
    session.$activity
      .receive(on: DispatchQueue.main)
      .removeDuplicates { $0.bookFingerprint == $1.bookFingerprint }
      .dropFirst()
      .sink { [weak self] activity in
        guard let self, self.currentSession === session else { return }
        Task {
          await self.joinPlayback(of: activity, in: session)
        }
      }
      .store(in: &sessionObservers)

    // if this device stops playing the coordinated book (switch, stop, delete),
    // exit the session instead of silently coordinating other content
    playerManager.currentItemPublisher()
      .receive(on: DispatchQueue.main)
      .dropFirst()
      .sink { [weak self] item in
        guard let self,
          !self.isReconfiguring,
          self.currentSession === session,
          let coordinatedRelativePath = self.coordinatedRelativePath,
          item?.relativePath != coordinatedRelativePath
        else { return }

        self.leaveCurrentSession()
      }
      .store(in: &sessionObservers)
  }

  private func handle(state: GroupSession<AudioBookActivity>.State, for session: GroupSession<AudioBookActivity>) {
    switch state {
    case .waiting:
      break
    case .joined:
      guard currentSession === session else { return }
      onSessionStateChange?(true)
    case .invalidated:
      guard currentSession === session else { return }
      handleSessionEnded()
    @unknown default:
      break
    }
  }

  private func handleSessionEnded() {
    playerManager.stopCoordinatingPlayback()
    currentSession = nil
    coordinatedRelativePath = nil
    teardownSessionObservers()
    onParticipantCountChange?(0)
    onSessionStateChange?(false)
  }

  private func teardownSessionObservers() {
    sessionObservers.removeAll()
  }

  /// One-shot await for the player's next `.bookReady`. Subscribes synchronously,
  /// so create it *before* triggering the load or a fast load can slip past it
  private func nextBookReadySignal() -> Task<Bool, Never> {
    let stream = AsyncStream<Bool> { continuation in
      let observer = NotificationCenter.default.addObserver(
        forName: .bookReady,
        object: nil,
        queue: .main
      ) { notification in
        continuation.yield(notification.userInfo?["loaded"] as? Bool == true)
        continuation.finish()
      }
      continuation.onTermination = { _ in
        NotificationCenter.default.removeObserver(observer)
      }
    }

    return Task {
      await withTaskGroup(of: Bool.self) { group in
        group.addTask {
          for await loaded in stream {
            return loaded
          }
          return false
        }
        // safety net: don't hang the join if the load dies without notifying
        group.addTask {
          try? await Task.sleep(nanoseconds: 30_000_000_000)
          return false
        }
        let result = await group.next() ?? false
        group.cancelAll()
        return result
      }
    }
  }
}
