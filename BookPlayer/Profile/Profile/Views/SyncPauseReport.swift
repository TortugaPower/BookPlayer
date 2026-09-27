//
//  SyncPauseReport.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import DeviceKit
import SwiftUI
import UIKit

/// What Report sends for a parked task: the task and why it stopped, every queued task
/// with its state, and the local library (paths with uuids), so support can see what the
/// device has and what it's still trying to tell the server. The server side is looked up
/// from its own records, so nothing is fetched here.
struct SyncPauseReport {
  static let supportEmail = "support@bookplayer.app"
  static let fileName = "bookplayer_sync_report.txt"

  let pausedTask: QueuedSyncTask
  let queuedTasks: [QueuedSyncTask]
  let library: [(relativePath: String, uuid: String)]
  let appVersion: String
  let systemVersion: String
  let deviceName: String

  var subject: String {
    "Sync paused (\(pausedTask.pause?.errorCode ?? "unknown")) - BookPlayer \(appVersion)"
  }

  var body: String {
    "<p>Hello,<br>A sync task in BookPlayer is paused and needs help.</p><br/>"
  }

  var text: String {
    var report = "BookPlayer sync report\n"
    report += "App: \(appVersion)\n"
    report += "Device: \(deviceName) \(systemVersion)\n"

    report += "\n-- Paused task --\n"
    report += describe(pausedTask)
    if let pause = pausedTask.pause {
      report += "  Message: \(pause.message)\n"
      report += "  Paused at: \(pause.pausedAt.ISO8601Format())\n"
      report += "  Sentry event: \(pause.sentryEventId ?? "none")\n"
    }

    report += "\n-- Queued tasks (\(queuedTasks.count)) --\n"
    for (index, task) in queuedTasks.enumerated() {
      report += "\n[\(index + 1)] " + describe(task)
    }

    report += "\n-- Local library (\(library.count)) --\n"
    report += LibraryTreeRepresentation.render(
      entries: library.map { ($0.relativePath, $0.uuid) },
      remoteIdentifiers: nil
    )
    return report
  }

  private func describe(_ task: QueuedSyncTask) -> String {
    var line = "\(task.jobType.rawValue) · lane \(task.queueKey)\n"
    if let pause = task.pause {
      let status = pause.httpStatus.map { " \($0)" } ?? ""
      line += "  Status: paused (\(pause.scope.rawValue)) · \(pause.errorCode)\(status)\n"
    } else {
      line += "  Status: pending\n"
    }
    line += "  Task ID: \(task.id)\n"
    line += "  Uuid: \(task.uuid)\n"
    line += "  Path: \(task.relativePath)\n"
    return line
  }

  /// The report as a named file, for the mail attachment and the share-sheet fallback
  func writeToTemporaryFile() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(Self.fileName)
    try Data(text.utf8).write(to: url, options: .atomic)
    return url
  }

  /// Same version string the support email uses: version-build plus the tier suffix
  static func appVersion(accessLevel: AccessLevel) -> String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    let suffix: String
    switch accessLevel {
    case .free:
      suffix = ""
    case .plus:
      suffix = "p"
    case .pro:
      suffix = "c"
    case .lite:
      suffix = "l"
    }
    return "\(version)-\(build)\(suffix)"
  }

  @MainActor
  static func make(
    for task: QueuedSyncTask,
    syncQueueService: SyncQueueServiceProtocol,
    libraryService: LibraryService,
    accessLevel: AccessLevel
  ) async -> SyncPauseReport {
    SyncPauseReport(
      pausedTask: task,
      queuedTasks: await syncQueueService.getOrderedQueuedJobs(activeTaskIDs: []),
      library: libraryService.fetchIdentifiersWithUuids(),
      appVersion: appVersion(accessLevel: accessLevel),
      systemVersion: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
      deviceName: "\(Device.current)"
    )
  }
}

/// The system share sheet, for sending a report when Mail isn't set up
struct ActivityView: UIViewControllerRepresentable {
  let activityItems: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
