//
//  DynamicAccessibilityLabel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/10/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import SwiftUI

/// A view modifier that provides dynamic accessibility labels for library items.
/// Updates the label in real-time when the item is currently playing (for books)
/// or when metadata changes (mark finished, progress updates, etc).
///
/// - Playing books: Subscribes to .bookPlaying notifications for live progress
/// - All items: Subscribes to immediateProgressUpdatePublisher for metadata changes
struct DynamicAccessibilityLabelModifier: ViewModifier {
  let item: SimpleLibraryItem

  @EnvironmentObject private var playerManager: PlayerManager
  @Environment(\.libraryService) private var libraryService
  @State private var accessibilityLabel: String
  @State private var cancellable: AnyCancellable?

  init(item: SimpleLibraryItem) {
    self.item = item
    self._accessibilityLabel = State(initialValue: VoiceOverService.getAccessibilityLabel(for: item))
  }

  func body(content: Content) -> some View {
    content
      .accessibilityLabel(accessibilityLabel)
      .onAppear {
        setupPlaybackObserver()
      }
      .onDisappear {
        cancellable?.cancel()
        cancellable = nil
      }
      .onReceive(
        libraryService.immediateProgressUpdatePublisher
          .filter { item.relativePath == $0["relativePath"] as? String }
      ) { params in
        // Skip if this item is playing — the .bookPlaying subscription handles it
        guard playerManager.currentItem?.relativePath != item.relativePath else { return }

        var updatedPercent = item.percentCompleted
        var updatedFinished = item.isFinished
        var updatedTime = item.currentTime

        if let percentCompleted = params["percentCompleted"] as? Double {
          updatedPercent = percentCompleted
        }
        if let isFinished = params["isFinished"] as? Bool {
          updatedFinished = isFinished
        }
        if let currentTime = params["currentTime"] as? Double {
          updatedTime = currentTime
        }

        let updatedItem = SimpleLibraryItem(
          title: item.title,
          details: item.details,
          speed: item.speed,
          currentTime: updatedTime,
          duration: item.duration,
          percentCompleted: updatedPercent,
          isFinished: updatedFinished,
          relativePath: item.relativePath,
          remoteURL: item.remoteURL,
          artworkURL: item.artworkURL,
          orderRank: item.orderRank,
          parentFolder: item.parentFolder,
          originalFileName: item.originalFileName,
          lastPlayDate: item.lastPlayDate,
          type: item.type
        )

        accessibilityLabel = VoiceOverService.getAccessibilityLabel(for: updatedItem)
      }
      .onChange(of: playerManager.currentItem?.relativePath) { oldPath, newPath in
        // Only books need the .bookPlaying subscription for live playback updates
        guard item.type == .book else { return }
        if newPath == item.relativePath || oldPath == item.relativePath {
          setupPlaybackObserver()
        }
      }
  }

  /// Sets up a .bookPlaying notification subscription for the currently playing book.
  /// Only activates when this item is the one being played.
  private func setupPlaybackObserver() {
    cancellable?.cancel()

    guard item.type == .book,
          let currentItem = playerManager.currentItem,
          currentItem.relativePath == item.relativePath else {
      cancellable = nil
      return
    }

    cancellable = NotificationCenter.default.publisher(for: .bookPlaying)
      .throttle(for: .seconds(10), scheduler: DispatchQueue.main, latest: true)
      .sink { [item] _ in
        guard let playingItem = self.playerManager.currentItem,
              playingItem.relativePath == item.relativePath else {
          return
        }

        let updatedItem = SimpleLibraryItem(
          title: item.title,
          details: item.details,
          speed: item.speed,
          currentTime: playingItem.currentTime,
          duration: item.duration,
          percentCompleted: playingItem.percentCompleted,
          isFinished: playingItem.isFinished,
          relativePath: item.relativePath,
          remoteURL: item.remoteURL,
          artworkURL: item.artworkURL,
          orderRank: item.orderRank,
          parentFolder: item.parentFolder,
          originalFileName: item.originalFileName,
          lastPlayDate: item.lastPlayDate,
          type: item.type
        )

        accessibilityLabel = VoiceOverService.getAccessibilityLabel(for: updatedItem)
      }
  }
}

extension View {
  /// Applies a dynamic accessibility label that updates when the item is playing.
  ///
  /// This modifier ensures VoiceOver users receive accurate information by subscribing
  /// to real-time updates via two mechanisms:
  ///
  /// - **Playing books**: .bookPlaying notification updates remaining time every 10 seconds
  /// - **All items**: immediateProgressUpdatePublisher catches metadata changes
  ///   (mark finished, progress updates, folder progress)
  ///
  /// - Parameter item: The library item to generate the accessibility label for
  /// - Returns: A view with a dynamically updating accessibility label
  func dynamicAccessibilityLabel(for item: SimpleLibraryItem) -> some View {
    modifier(DynamicAccessibilityLabelModifier(item: item))
  }
}
