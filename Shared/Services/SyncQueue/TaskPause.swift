//
//  TaskPause.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// How much of the queue a parked task holds back
public enum TaskPauseScope: String {
  /// Only this task waits; the rest of its lane keeps running (leaf tasks nothing
  /// later depends on)
  case task
  /// The whole lane waits behind it: running later tasks would build on a change the
  /// server never got (structural sync-lane tasks)
  case lane
  /// Every BookPlayer-server lane waits: the server rejected the account itself
  case account
}

/// Why a task stopped: the server's coded answer, kept for the Queued Tasks row and Report
public struct TaskPause: Equatable {
  public let scope: TaskPauseScope
  public let errorCode: String
  /// The server's message. Shown to the user and attached to Report, never sent to Sentry
  /// (it embeds file names)
  public let message: String
  public let httpStatus: Int?
  public let pausedAt: Date
  public let sentryEventId: String?

  public init(
    scope: TaskPauseScope,
    errorCode: String,
    message: String,
    httpStatus: Int?,
    pausedAt: Date,
    sentryEventId: String? = nil
  ) {
    self.scope = scope
    self.errorCode = errorCode
    self.message = message
    self.httpStatus = httpStatus
    self.pausedAt = pausedAt
    self.sentryEventId = sentryEventId
  }
}

/// What a fresh RevenueCat read says about the server's rejection of the account
public enum AccountVerdict: Equatable {
  /// No sync tier left: the account update runs the lapse path
  case lapsed
  /// LITE, at a route that needs PRO: the server was right, and the task can never run
  case lacksPro
  /// RevenueCat grants what the server refused, or couldn't be read
  case disputed
}

/// What the queue does with a failed task
public enum SyncFailureAction: Equatable {
  /// Uncoded or transient: retry after the usual delay, as always
  case retry
  /// Stop the task with this scope until a launch retry or the user's Retry
  case park(TaskPauseScope)
  /// Coded failure where nobody can see a paused task (watch): log and drop it
  case drop
  /// The server rejected the account: confirm against RevenueCat, holding every
  /// server lane meanwhile
  case verifyAccount
}

/// A failure that says it can never succeed as it is: the server's coded 4xx, or a book
/// the app itself refuses to upload
public struct CodedFailure: Equatable {
  public let code: String
  public let message: String
  public let httpStatus: Int?
}

public enum SyncFailurePolicy {
  /// Codes about the account, not the task
  static let accountCodes: Set<String> = ["not_subscribed", "tier_required"]

  /// nil for anything uncoded (network, 5xx, cancellation): those keep retrying
  public static func codedFailure(_ error: Error?) -> CodedFailure? {
    if let error = error as? UploadFileError {
      return CodedFailure(code: error.code, message: error.message, httpStatus: nil)
    }
    guard
      let error = error as? BookPlayerError,
      case .networkErrorWithCode(let message, let code, let status) = error
    else { return nil }
    return CodedFailure(code: code, message: message, httpStatus: status)
  }

  /// Judged by the task, not the code: only the S3 routes (book files and artwork) need PRO,
  /// every other route takes either sync tier, and the server's `tier_required` and
  /// `not_subscribed` both mean "not the tier this route needs".
  public static func accountVerdict(for jobType: SyncJobType, freshLevel: AccessLevel?) -> AccountVerdict {
    switch freshLevel {
    case nil, .pro?:
      return .disputed
    case .lite?:
      return [.uploadFile, .uploadArtwork].contains(jobType) ? .lacksPro : .disputed
    case .plus?, .free?:
      return .lapsed
    }
  }

  /// Only a coded failure parks: a code means the request can never succeed as sent.
  /// Anything uncoded keeps retrying, so a new server failure mode never strands tasks.
  public static func action(
    for error: Error?,
    jobType: SyncJobType,
    parkingEnabled: Bool
  ) -> SyncFailureAction {
    guard let code = codedFailure(error)?.code else { return .retry }

    // Media-server pushes never hit the BookPlayer server; their own failure handling
    // stands, and an account pause must never land on a provider lane
    if jobType == .externalUpdate { return .retry }

    if accountCodes.contains(code) { return .verifyAccount }

    guard parkingEnabled else { return .drop }
    return .park(scope(for: jobType))
  }

  /// Leaf tasks park alone: nothing later in the queue depends on them. Every other
  /// sync-lane task changes structure (what exists, where, under which uuid) that later
  /// tasks build on, so the lane stops behind it.
  public static func scope(for jobType: SyncJobType) -> TaskPauseScope {
    switch jobType {
    case .update, .uploadArtwork, .uploadFile, .externalUpdate:
      return .task
    case .upload, .move, .renameFolder, .delete, .shallowDelete, .setBookmark, .deleteBookmark,
        .matchUuid, .externalResource, .externalResourceToDownload, .deleteExternalResource:
      return .lane
    }
  }
}
