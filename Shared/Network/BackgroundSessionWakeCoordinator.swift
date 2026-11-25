//
//  BackgroundSessionWakeCoordinator.swift
//  BookPlayerKit
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// Answers the system when it relaunches or wakes the app for a background session's events:
/// iOS's `application(_:handleEventsForBackgroundURLSession:completionHandler:)`, watchOS's
/// `WKURLSessionRefreshBackgroundTask`. Answering lets the system suspend the app, so for the
/// upload sessions it waits until the upload has handled the finished parts and handed the
/// session the next ones — calling it earlier froze those requests until the next wake (P2b) —
/// and for the downloads until each finished or stopped one is handled (moved and verified, or
/// resumed). Either order of the handler and the session's "finished events" callback works:
/// the spike saw both.
@MainActor
public final class BackgroundSessionWakeCoordinator: BPLogger {
  public struct Dependencies {
    /// Recreates the session(s) behind an identifier, so the system delivers their events
    var activateSessions: (String) -> Void
    /// The upload queue's `settleUploads()`
    var settleUploads: () async -> Void
    /// `SyncService.settleDownloads()`: the finished downloads' follow-up work
    var settleDownloads: () async -> Void
    /// Asks for time to settle in the background, with what to do when it runs out, and returns
    /// how to give it back. Nil when there's none to ask for: watchOS's wake is itself the time.
    var beginBackgroundTime: (@escaping () -> Void) -> (() -> Void)?
    /// Longest wait before answering the system anyway
    var timeout: Duration
    /// A "finished events" older than this belongs to an earlier wake, not the next one
    var staleEventsAfter: TimeInterval

    public init(
      activateSessions: @escaping (String) -> Void,
      settleUploads: @escaping () async -> Void,
      settleDownloads: @escaping () async -> Void,
      beginBackgroundTime: @escaping (@escaping () -> Void) -> (() -> Void)?,
      timeout: Duration,
      staleEventsAfter: TimeInterval = 60
    ) {
      self.activateSessions = activateSessions
      self.settleUploads = settleUploads
      self.settleDownloads = settleDownloads
      self.beginBackgroundTime = beginBackgroundTime
      self.timeout = timeout
      self.staleEventsAfter = staleEventsAfter
    }
  }

  private let dependencies: Dependencies
  /// Per session, this wake's handler; the token keeps a timer from an earlier wake from
  /// answering a later one
  private var handlers = [String: (token: UUID, handler: () -> Void)]()
  /// Sessions whose events finished before the system handed over their handler, and when
  private var finishedWithoutHandler = [String: Date]()
  private var observer: NSObjectProtocol?

  public init(dependencies: Dependencies) {
    self.dependencies = dependencies
    observer = NotificationCenter.default.addObserver(
      forName: .backgroundSessionFinishedEvents,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let identifier = notification.object as? String else { return }
      MainActor.assumeIsolated {
        self?.sessionFinishedEvents(identifier)
      }
    }
  }

  deinit {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  public func handleEvents(forSession identifier: String, completionHandler: @escaping () -> Void) {
    Self.logger.info("Woken for background session \(identifier)")
    // Anything else (e.g. the single-file media-server downloads, whose queue lives only in
    // memory) has nothing to resume in the background
    guard isOwned(identifier) else {
      completionHandler()
      return
    }

    // A new wake for the same session: the earlier one's handler is still owed an answer
    if let previous = handlers[identifier] {
      Self.logger.info("Background session \(identifier): superseded by a new wake")
      previous.handler()
    }
    let token = UUID()
    handlers[identifier] = (token, completionHandler)
    dependencies.activateSessions(identifier)

    if let finishedAt = finishedWithoutHandler.removeValue(forKey: identifier),
       Date().timeIntervalSince(finishedAt) < dependencies.staleEventsAfter {
      answer(identifier, token: token)
    } else {
      // The session may never report back (e.g. it isn't created in this launch)
      scheduleFallback(for: identifier, token: token)
    }
  }

  private func sessionFinishedEvents(_ identifier: String) {
    guard isOwned(identifier) else { return }
    guard let token = handlers[identifier]?.token else {
      finishedWithoutHandler[identifier] = Date()
      return
    }
    answer(identifier, token: token)
  }

  private func isOwned(_ identifier: String) -> Bool {
    BackgroundTransferSessions.uploadIdentifiers.contains(identifier)
      || identifier == BackgroundTransferSessions.downloadIdentifier
  }

  /// The session's work settles first, under a background task on iOS so it isn't frozen
  /// mid-request or mid-write: uploads queue their next parts; downloads finish their
  /// follow-up (chapters, verification, scheduling — Core Data in the App Group container) or
  /// resume
  private func answer(_ identifier: String, token: UUID) {
    let settle = BackgroundTransferSessions.uploadIdentifiers.contains(identifier)
      ? dependencies.settleUploads
      : dependencies.settleDownloads

    var endBackgroundTime: (() -> Void)?
    let finish: (String) -> Void = { [weak self] reason in
      self?.callHandler(for: identifier, token: token, reason: reason)
      endBackgroundTime?()
      endBackgroundTime = nil
    }
    // iOS calls the expiration handler on the main thread and expects the task ended there
    endBackgroundTime = dependencies.beginBackgroundTime {
      MainActor.assumeIsolated { finish("background time expired") }
    }
    Task {
      await settle()
      finish("settled")
    }
    Task {
      try? await Task.sleep(for: dependencies.timeout)
      finish("timed out")
    }
  }

  private func scheduleFallback(for identifier: String, token: UUID) {
    Task {
      try? await Task.sleep(for: dependencies.timeout)
      callHandler(for: identifier, token: token, reason: "no events reported")
    }
  }

  /// Once per wake: the first of settle, timeout or expiration wins
  private func callHandler(for identifier: String, token: UUID, reason: String) {
    guard let entry = handlers[identifier], entry.token == token else { return }
    handlers[identifier] = nil
    Self.logger.info("Background session \(identifier) done (\(reason))")
    entry.handler()
  }
}
