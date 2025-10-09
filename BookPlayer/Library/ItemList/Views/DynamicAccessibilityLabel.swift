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
/// or when child items are playing (for folders), ensuring VoiceOver users get
/// accurate remaining time and progress information.
///
/// For books: Subscribes to currentTime updates from PlayerManager
/// For folders: Subscribes to .folderProgressUpdated notifications
struct DynamicAccessibilityLabelModifier: ViewModifier {
  let item: SimpleLibraryItem
  
  @EnvironmentObject private var playerManager: PlayerManager
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
        setupObserver()
      }
      .onDisappear {
        cancellable?.cancel()
      }
      .onChange(of: playerManager.currentItem?.relativePath) { _, _ in
        // Re-setup observer when the playing item changes
        setupObserver()
      }
  }
  
  private func setupObserver() {
    cancellable?.cancel()
    
    // Handle differently based on item type
    if item.type == .book {
      setupBookObserver()
    } else {
      setupFolderObserver()
    }
  }
  
  private func setupBookObserver() {
    // Only observe if this book is currently playing
    guard let currentItem = playerManager.currentItem,
          currentItem.relativePath == item.relativePath else {
      // Item is not playing, use static label
      accessibilityLabel = VoiceOverService.getAccessibilityLabel(for: item)
      return
    }
    
    // Subscribe to currentTime updates via the currentProgressPublisher
    // This is the same mechanism used by ItemProgressView
    cancellable = playerManager.currentProgressPublisher()
      .filter { [item] (relativePath, _) in
        relativePath == item.relativePath
      }
      .throttle(for: .seconds(10), scheduler: DispatchQueue.main, latest: true)
      .sink { [item] (_, _) in
        // Get the current playing item to access updated currentTime
        guard let playingItem = self.playerManager.currentItem,
              playingItem.relativePath == item.relativePath else {
          return
        }
        
        // Create an updated SimpleLibraryItem with the new currentTime
        let updatedItem = SimpleLibraryItem(
          title: item.title,
          details: item.details,
          speed: item.speed,
          currentTime: playingItem.currentTime,
          duration: item.duration,
          percentCompleted: playingItem.percentCompleted,
          isFinished: item.isFinished,
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
  
  private func setupFolderObserver() {
    // For folders, subscribe to folder progress updates
    // This is triggered when any book inside the folder is playing
    cancellable = NotificationCenter.default.publisher(for: .folderProgressUpdated)
      .throttle(for: .seconds(10), scheduler: DispatchQueue.main, latest: true)
      .filter { [item] notification in
        guard
          let relativePath = notification.userInfo?["relativePath"] as? String,
          item.relativePath == relativePath
        else {
          return false
        }
        return true
      }
      .sink { [item] notification in
        guard let progress = notification.userInfo?["progress"] as? Double else { return }
        
        // Create an updated SimpleLibraryItem with the new progress
        let updatedItem = SimpleLibraryItem(
          title: item.title,
          details: item.details,
          speed: item.speed,
          currentTime: item.currentTime,
          duration: item.duration,
          percentCompleted: progress,
          isFinished: item.isFinished,
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
  /// to real-time updates from the PlayerManager (for books) or folder progress
  /// notifications (for folders with playing child items).
  ///
  /// - Books: Updates remaining time every 10 seconds when playing
  /// - Folders: Updates progress percentage when any child item is playing
  ///
  /// - Parameter item: The library item to generate the accessibility label for
  /// - Returns: A view with a dynamically updating accessibility label
  func dynamicAccessibilityLabel(for item: SimpleLibraryItem) -> some View {
    modifier(DynamicAccessibilityLabelModifier(item: item))
  }
}

