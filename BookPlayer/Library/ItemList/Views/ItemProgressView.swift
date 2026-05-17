//
//  ItemProgressView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 23/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ItemProgressView: View {
  /// Throttle window applied to per-row progress publishers. Each visible row in a long
  /// library list subscribes to three high-frequency progress streams; without throttling
  /// SwiftUI re-diffs the circular indicators on every audio tick, which lags VoiceOver
  /// and burns CPU. One second matches the existing `.folderProgressUpdated` cadence and
  /// keeps the list feeling live.
  private static let progressUpdateThrottleSeconds = 1

  let item: SimpleLibraryItem
  let isHighlighted: Bool

  @State private var progress: Double
  @State private var isFinished: Bool
  @EnvironmentObject private var playerManager: PlayerManager
  @Environment(\.libraryService) private var libraryService

  /// Set from `LibraryOptionsView`. When true the row shows a numeric
  /// percentage instead of the circular wheel.
  @AppStorage(
    wrappedValue: false,
    Constants.UserDefaults.libraryDisplayProgressStyle,
    store: UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)
  )
  private var progressAsPercentage: Bool

  init(item: SimpleLibraryItem, isHighlighted: Bool) {
    self.item = item
    self.isHighlighted = isHighlighted
    self._progress = .init(initialValue: item.percentCompleted / 100)
    self._isFinished = .init(initialValue: item.isFinished)
  }

  var body: some View {
    Group {
      if progressAsPercentage {
        PercentageProgressView(
          progress: isFinished ? 1.0 : progress,
          isHighlighted: isHighlighted
        )
      } else {
        CircularProgressView(
          progress: isFinished ? 1.0 : progress,
          isHighlighted: isHighlighted
        )
      }
    }
    .onReceive(
      playerManager.currentProgressPublisher()
        .filter { $0.0 == item.relativePath }
        .throttle(for: .seconds(Self.progressUpdateThrottleSeconds), scheduler: DispatchQueue.main, latest: true)
    ) { (_, progress) in
      self.progress = progress
    }
    .onReceive(
      libraryService.immediateProgressUpdatePublisher
        .filter { item.relativePath == $0["relativePath"] as? String }
        .throttle(for: .seconds(Self.progressUpdateThrottleSeconds), scheduler: DispatchQueue.main, latest: true)
    ) { params in
      if let percentCompleted = params["percentCompleted"] as? Double {
        self.progress = percentCompleted / 100
      }
      if let isFinished = params["isFinished"] as? Bool {
        self.isFinished = isFinished
      }
    }
    .onReceive(
      NotificationCenter.default.publisher(for: .folderProgressUpdated)
        .throttle(for: .seconds(Self.progressUpdateThrottleSeconds), scheduler: DispatchQueue.main, latest: true)
        .filter { notification in
          guard
            item.type != .book,
            let relativePath = notification.userInfo?["relativePath"] as? String,
            item.relativePath == relativePath
          else {
            return false
          }

          return true
        }
    ) { notification in
      guard let progress = notification.userInfo?["progress"] as? Double else { return }
      self.progress = progress / 100
    }
  }
}
