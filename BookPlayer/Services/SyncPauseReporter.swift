//
//  SyncPauseReporter.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import Sentry

/// Reports each parked sync task to Sentry once, so a new failure kind surfaces without
/// waiting for a support email. The event carries only what identifies the failure — job
/// type, error code, HTTP status, lane, pause scope and the item's uuid (to look it up in
/// the server's sync log). Never the server's message or the item's path: both embed file
/// names — and no breadcrumbs, since our own API's request breadcrumbs keep their query
/// strings, which carry `relativePath`. The fingerprint groups one issue per job type and
/// error code.
final class SyncPauseReporter: BPLogger {
  private let syncQueueService: SyncQueueServiceProtocol
  private let capture: (Event) -> SentryId
  /// This session's reports: the event id is written back to the task asynchronously, so a
  /// quick re-park (Retry that fails the same way) could otherwise arrive before it lands
  private var reportedTaskIds = Set<String>()
  private var observer: NSObjectProtocol?

  init(
    syncQueueService: SyncQueueServiceProtocol,
    capture: @escaping (Event) -> SentryId = { event in
      SentrySDK.capture(event: event) { scope in scope.clearBreadcrumbs() }
    }
  ) {
    self.syncQueueService = syncQueueService
    self.capture = capture
    // The queue posts on main
    observer = NotificationCenter.default.addObserver(
      forName: .syncTaskPaused,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let task = notification.object as? QueuedSyncTask else { return }
      self?.report(task)
    }
  }

  deinit {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  func report(_ task: QueuedSyncTask) {
    guard
      let pause = task.pause,
      pause.sentryEventId == nil,
      reportedTaskIds.insert(task.id).inserted
    else { return }

    let event = Event(level: .warning)
    event.message = SentryMessage(formatted: "Sync task paused: \(task.jobType.rawValue) \(pause.errorCode)")
    event.fingerprint = ["sync-paused", task.jobType.rawValue, pause.errorCode]
    var tags = [
      "sync.job_type": task.jobType.rawValue,
      "sync.error_code": pause.errorCode,
      "sync.lane": task.queueKey,
      "sync.pause_scope": pause.scope.rawValue,
    ]
    if let status = pause.httpStatus {
      tags["sync.http_status"] = String(status)
    }
    event.tags = tags
    event.extra = ["item_uuid": task.uuid]

    let eventId = capture(event)
    // Crash reports off: nothing was sent, so the task stays unreported (here too) for when
    // they're turned back on
    guard eventId != SentryId.empty else {
      reportedTaskIds.remove(task.id)
      return
    }
    syncQueueService.recordPauseReport(eventId: eventId.sentryIdString, forTask: task.id)
  }
}
