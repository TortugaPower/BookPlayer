//
//  ProgressLabelsSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ProgressLabelsSectionView: View {
  @AppStorage(Constants.UserDefaults.remainingTimeEnabled, store: UserDefaults.sharedDefaults) var prefersRemainingTime: Bool = true
  @AppStorage(Constants.UserDefaults.chapterContextEnabled, store: UserDefaults.sharedDefaults) var prefersChapterContext: Bool = true
  @AppStorage(Constants.UserDefaults.bookRemainingTimeEnabled, store: UserDefaults.sharedDefaults) var prefersBookRemaining: Bool = false

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    ThemedSection {
      Toggle(isOn: $prefersRemainingTime) {
        Text("settings_remainingtime_title")
          .bpFont(.body)
      }
      .onChange(of: prefersRemainingTime) {
        handleValueUpdated()
      }
      Toggle(isOn: $prefersChapterContext) {
        Text("settings_chaptercontext_title")
          .bpFont(.body)
      }
      .onChange(of: prefersChapterContext) {
        handleValueUpdated()
      }
      Toggle(isOn: $prefersBookRemaining) {
        Text("settings_bookremaining_title")
          .bpFont(.body)
      }
      .onChange(of: prefersBookRemaining) {
        handleValueUpdated()
      }
      .disabled(!prefersChapterContext)
    } header: {
      Text("settings_progresslabels_title")
        .bpFont(.subheadline)
        .foregroundStyle(theme.secondaryColor)
    }
    .listSectionSpacing(Spacing.S1)

    ThemedSection {
      ProgressLabelsPreview(
        prefersChapterContext: prefersChapterContext,
        prefersRemainingTime: prefersRemainingTime,
        prefersBookRemaining: prefersBookRemaining
      )
      .listRowBackground(Color.clear)
    } footer: {
      Text("settings_progresslabels_description")
        .bpFont(.caption)
        .foregroundStyle(theme.secondaryColor)
    }
  }

  func handleValueUpdated() {
    /// Notify player screen
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.updateProgress)
  }
}

/// Non-interactive illustration of the player's progress labels, reflecting the
/// current toggle selections. Uses a fixed sample book so users can see how the
/// labels behave before opening the player.
private struct ProgressLabelsPreview: View {
  let prefersChapterContext: Bool
  let prefersRemainingTime: Bool
  let prefersBookRemaining: Bool

  @EnvironmentObject var theme: ThemeViewModel

  // Sample scenario: 46:00 into chapter 3 of 18 of an 8h book.
  private let bookDuration: TimeInterval = 8 * 3600
  private let currentTime: TimeInterval = 2760
  private let chapterStart: TimeInterval = 2400
  private let chapterDuration: TimeInterval = 1080
  private let chapterIndex = 3
  private let chapterCount = 18

  private var sliderValue: Double {
    prefersChapterContext
      ? (currentTime - chapterStart) / chapterDuration
      : currentTime / bookDuration
  }

  private var currentTimeText: String {
    TimeParser.formatTime(
      prefersChapterContext ? currentTime - chapterStart : currentTime
    )
  }

  private var progressText: String {
    guard prefersChapterContext else {
      return "\(Int(round(currentTime / bookDuration * 100)))%"
    }

    if prefersBookRemaining {
      return String.localizedStringWithFormat(
        "player_book_remaining_title".localized,
        TimeParser.formatRemaining(bookDuration - currentTime)
      )
    }

    return String.localizedStringWithFormat(
      "player_chapter_description".localized,
      chapterIndex,
      chapterCount
    )
  }

  private var maxTimeText: String {
    let value: TimeInterval
    if prefersChapterContext {
      value = prefersRemainingTime ? (currentTime - chapterStart) - chapterDuration : chapterDuration
    } else {
      value = prefersRemainingTime ? currentTime - bookDuration : bookDuration
    }

    let formatted = TimeParser.formatTime(abs(value))
    return value < 0 ? "-".appending(formatted) : formatted
  }

  var body: some View {
    VStack(spacing: 8) {
      ProgressView(value: sliderValue)
        .tint(theme.linkColor)

      HStack {
        Text(currentTimeText)
          .bpFont(.miniPlayerTitle).monospacedDigit()
          .frame(maxWidth: .infinity, alignment: .leading)

        Spacer()

        Text(progressText)
          .lineLimit(1)
          .bpFont(.miniPlayerTitle)
          .layoutPriority(1)

        Spacer()

        Text(maxTimeText)
          .bpFont(.miniPlayerTitle).monospacedDigit()
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .foregroundColor(.secondary)
    }
    .padding(.vertical, 8)
    .accessibilityHidden(true)
  }
}

#Preview {
  Form {
    ProgressLabelsSectionView()
  }
  .environmentObject(ThemeViewModel())
}
