//
//  QueuedTaskDisplay.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

/// Display metadata for a task queue key
enum QueueDisplay {
  static func name(for queueKey: String) -> String {
    switch queueKey {
    case TaskQueueKey.sync:
      return "queue_library_sync_title".localized
    case TaskQueueKey.uploadFile:
      return "queue_file_uploads_title".localized
    default:
      return queueKey.capitalized
    }
  }

  static func imageName(for queueKey: String) -> String {
    switch queueKey {
    case TaskQueueKey.sync:
      return "arrow.triangle.2.circlepath.icloud"
    case TaskQueueKey.uploadFile:
      return "square.and.arrow.up.badge.clock"
    default:
      return "antenna.radiowaves.left.and.right"
    }
  }
}

/// One collapsible lane on the Queued Tasks screen
struct QueuedTaskSection: Identifiable {
  let queueKey: String
  let tasks: [ConcurrentSyncTask]

  var id: String { queueKey }
}

extension Array where Element == ConcurrentSyncTask {
  /// Lanes in display order — the sync lane first, then alphabetically — each keeping the
  /// engine's order (active tasks first) for its own rows. A drained lane has no section.
  func groupedByLane() -> [QueuedTaskSection] {
    var laneOrder = [String]()
    var tasksByLane = [String: [ConcurrentSyncTask]]()
    for task in self {
      if tasksByLane[task.queueKey] == nil {
        laneOrder.append(task.queueKey)
      }
      tasksByLane[task.queueKey, default: []].append(task)
    }

    return laneOrder
      .sorted { lhs, rhs in
        if lhs == TaskQueueKey.sync { return true }
        if rhs == TaskQueueKey.sync { return false }
        return lhs < rhs
      }
      .map { QueuedTaskSection(queueKey: $0, tasks: tasksByLane[$0] ?? []) }
  }
}

extension ConcurrentSyncTask {
  /// Sync-lane jobs name the item they touch (the library match names the whole library);
  /// file uploads and provider pushes describe the work instead.
  var displayTitle: String {
    switch jobType {
    case .matchUuid:
      return "sync_library_title".localized
    case .uploadFile:
      return "task_uploading_file_label".localized
    case .externalUpdate:
      return String(format: "task_updating_progress_label".localized, QueueDisplay.name(for: queueKey))
    default:
      return relativePath
    }
  }

  var displayImageName: String {
    switch jobType {
    case .upload:
      return "arrow.up.to.line"
    case .update:
      return "arrow.2.circlepath"
    case .move:
      return "arrow.forward"
    case .renameFolder:
      return "square.and.pencil"
    case .delete:
      return "xmark.bin.fill"
    case .shallowDelete:
      return "xmark.bin"
    case .setBookmark:
      return "bookmark"
    case .deleteBookmark:
      return "bookmark.slash"
    case .uploadArtwork:
      return "photo"
    case .matchUuid:
      return "app.connected.to.app.below.fill"
    case .externalResource:
      return "arrow.up.forward.square"
    case .externalResourceToDownload:
      return "link.badge.plus"
    case .deleteExternalResource:
      return "xmark.bin"
    case .externalUpdate:
      return "arrow.2.circlepath"
    case .uploadFile:
      return "square.and.arrow.up.badge.clock"
    }
  }

  /// Byte progress arrives through `.uploadProgressUpdated` for the file moving to S3;
  /// every other job is an API round-trip with no meaningful percentage.
  var tracksByteProgress: Bool {
    jobType == .upload || jobType == .uploadFile
  }
}
