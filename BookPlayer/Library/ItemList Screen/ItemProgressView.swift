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
  @EnvironmentObject private var playerManager: PlayerManager

  init(item: SimpleLibraryItem, isHighlighted: Bool) {
    self.item = item
    self.isHighlighted = isHighlighted
    self._progress = .init(initialValue: item.progress)
  }

  var body: some View {
    CircularProgressView(
      progress: progress,
      isHighlighted: isHighlighted
    )
    .onReceive(
      playerManager.currentProgressPublisher()
        .filter { $0.0 == item.relativePath }
    ) { (_, progress) in
      self.progress = progress
    }
    .onReceive(
      NotificationCenter.default.publisher(for: .folderProgressUpdated)
        .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: false)
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
