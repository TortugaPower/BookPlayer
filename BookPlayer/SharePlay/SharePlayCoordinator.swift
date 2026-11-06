//
//  SharePlayCoordinator.swift
//  BookPlayer
//
//  Created by dawsonamf on 6/28/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
import GroupActivities
import UIKit

enum SharePlayStartResult {
  case activated
  /// No FaceTime/Messages context to activate into; offer the system sharing sheet.
  case needsSharingSheet
  case cancelled
}

@MainActor
final class SharePlayCoordinator: ObservableObject {
  @Published private(set) var isInSession = false
  @Published private(set) var participantCount = 0

  private let service: SharePlayService
  private let groupStateObserver = GroupStateObserver()

  init(
    playerManager: SharePlayCoordinating,
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    playerLoaderService: PlayerLoaderService
  ) {
    self.service = SharePlayService(
      playerManager: playerManager,
      libraryService: libraryService,
      playbackService: playbackService,
      playerLoaderService: playerLoaderService
    )

    service.onSessionStateChange = { [weak self] isActive in
      self?.isInSession = isActive
    }
    service.onParticipantCountChange = { [weak self] count in
      self?.participantCount = count
    }
    service.onJoinFailure = { [weak self] reason, activity in
      self?.presentJoinFailure(reason, for: activity)
    }

    service.startListening()
  }

  func makeActivity(for item: PlayableItem) -> AudioBookActivity {
    AudioBookActivity(
      bookFingerprint: BookFingerprint(from: item),
      bookTitle: item.title,
      bookAuthor: BookFingerprint.normalizeAuthor(item.author).isEmpty ? "" : item.author
    )
  }

  func startSession(for item: PlayableItem) async -> SharePlayStartResult {
    guard groupStateObserver.isEligibleForGroupSession else {
      return .needsSharingSheet
    }

    let activity = makeActivity(for: item)

    switch await activity.prepareForActivation() {
    case .activationPreferred:
      let activated = (try? await activity.activate()) ?? false
      return activated ? .activated : .cancelled
    case .activationDisabled:
      return .cancelled
    case .cancelled:
      return .cancelled
    @unknown default:
      return .cancelled
    }
  }

  func leaveSession() {
    service.leaveCurrentSession()
  }

  func endSession() {
    service.endCurrentSession()
  }

  private func presentJoinFailure(_ reason: SharePlayJoinFailure, for activity: AudioBookActivity) {
    let author = activity.bookAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
    let subject =
      author.isEmpty
      ? "\"\(activity.bookTitle)\""
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
