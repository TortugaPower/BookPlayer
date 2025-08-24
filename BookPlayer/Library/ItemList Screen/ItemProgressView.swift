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
  }
}
