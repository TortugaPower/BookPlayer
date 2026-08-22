//
//  ReviewPromptService.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import StoreKit
import UIKit

/// Owns the cooldown for the App Store review prompt.
///
/// Finishing a book arms `Constants.UserDefaults.pendingReviewPrompt`; this service consumes
/// the flag and forwards to StoreKit at most once per app version and once per cooldown window,
/// since the system's own 3-per-365-days throttle effectively resets across app updates.
///
/// Callers must only evaluate while the app is active, so the armed flag isn't consumed when
/// the prompt has no chance of being shown.
@MainActor
final class ReviewPromptService {
  /// Self-imposed cap of ~3 prompts per year, independent of the system throttle
  private static let cooldownInterval: TimeInterval = 120 * 24 * 60 * 60

  private let defaults: UserDefaults
  private let dateProvider: () -> Date
  private let versionProvider: () -> String?
  private let presentPromptOverride: (() -> Void)?

  init(
    defaults: UserDefaults = .standard,
    dateProvider: @escaping () -> Date = { Date() },
    versionProvider: @escaping () -> String? = {
      Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    },
    presentPrompt: (() -> Void)? = nil
  ) {
    self.defaults = defaults
    self.dateProvider = dateProvider
    self.versionProvider = versionProvider
    self.presentPromptOverride = presentPrompt
  }

  func requestReviewIfEligible() {
    guard defaults.bool(forKey: Constants.UserDefaults.pendingReviewPrompt) else { return }

    /// Consume the flag even when ineligible, so a prompt only ever fires
    /// within one session of an actual book finish
    defaults.set(false, forKey: Constants.UserDefaults.pendingReviewPrompt)

    guard hasCooldownElapsed(), isNewVersionSinceLastRequest() else { return }

    if let presentPromptOverride {
      presentPromptOverride()
    } else {
      presentSystemPrompt()
    }

    /// There's no callback for whether the prompt was actually shown; the request itself
    /// spends the cooldown window
    defaults.set(dateProvider(), forKey: Constants.UserDefaults.lastReviewRequestDate)
    defaults.set(versionProvider(), forKey: Constants.UserDefaults.lastReviewRequestVersion)
  }

  private func hasCooldownElapsed() -> Bool {
    guard
      let lastRequest = defaults.object(
        forKey: Constants.UserDefaults.lastReviewRequestDate
      ) as? Date
    else {
      return true
    }

    let now = dateProvider()

    guard lastRequest <= now else {
      /// The clock moved backwards; rewrite the stored date so the cooldown can elapse again
      defaults.set(now, forKey: Constants.UserDefaults.lastReviewRequestDate)
      return false
    }

    return now.timeIntervalSince(lastRequest) >= Self.cooldownInterval
  }

  private func isNewVersionSinceLastRequest() -> Bool {
    guard
      let lastVersion = defaults.string(
        forKey: Constants.UserDefaults.lastReviewRequestVersion
      )
    else {
      return true
    }

    return versionProvider() != lastVersion
  }

  private func presentSystemPrompt() {
#if RELEASE
    if let scene = UIApplication.shared.connectedScenes.first(where: {
      $0.activationState == .foregroundActive
    }) as? UIWindowScene {
      AppStore.requestReview(in: scene)
    }
#endif
  }
}
