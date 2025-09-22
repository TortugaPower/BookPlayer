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
  let item: SimpleLibraryItem
  let isHighlighted: Bool

  @State private var progress: Double
  @State private var isFinished: Bool
  @EnvironmentObject private var playerManager: PlayerManager
  @Environment(\.libraryService) private var libraryService

  init(item: SimpleLibraryItem, isHighlighted: Bool) {
    self.item = item
    self.isHighlighted = isHighlighted
    self._progress = .init(initialValue: item.percentCompleted / 100)
    self._isFinished = .init(initialValue: item.isFinished)
  }

  var body: some View {
    CircularProgressView(
      progress: isFinished ? 1.0 : progress,
      isHighlighted: isHighlighted
    )
    .onReceive(
      playerManager.currentProgressPublisher()
        .filter { $0.0 == item.relativePath }
    ) { (_, progress) in
      self.progress = progress
    }
    .onReceive(
      libraryService.immediateProgressUpdatePublisher
        .filter { item.relativePath == $0["relativePath"] as? String }
    ) { params in
      if let percentCompleted = params["percentCompleted"] as? Double {
        self.progress = percentCompleted / 100
      } else if let isFinished = params["isFinished"] as? Bool {
        self.isFinished = isFinished
      }
    }
    .onReceive(
      NotificationCenter.default.publisher(for: .folderProgressUpdated)
        .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
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
