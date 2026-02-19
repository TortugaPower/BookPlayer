//
//  NavigationRowView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct NavigationRowView: View {
  @EnvironmentObject private var playerManager: PlayerManager
  @EnvironmentObject private var theme: ThemeViewModel
  
  var playerTitle: String
  var hasNextChapter: Bool = false
  var hasPreviousChapter: Bool = false
  
  var body: some View {
    HStack(spacing: 4) {
      HStack(spacing: 16) {
        Button {
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          if let currentChapter = self.playerManager.currentItem?.currentChapter,
            let previousChapter = self.playerManager.currentItem?.previousChapter(before: currentChapter)
          {
            self.playerManager.jumpToChapter(previousChapter)
          } else {
            self.playerManager.playPreviousItem()
          }
          NotificationCenter.default.post(name: .listeningProgressChanged, object: nil)
        } label: {
          Image(systemName: hasPreviousChapter ? "chevron.left" : "chevron.left.2").tint(theme.primaryColor)
        }
          .accessibilityLabel("chapters_previous_title".localized)
      }
      
      Spacer()
      
      Text(playerTitle)
        .bpFont(.headline)
        .foregroundColor(theme.primaryColor)
        .multilineTextAlignment(.center)
        .frame(height: 56)
      
      Spacer()
      
      HStack(spacing: 16) {
        Button {
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()

          if let currentChapter = self.playerManager.currentItem?.currentChapter,
            let nextChapter = self.playerManager.currentItem?.nextChapter(after: currentChapter)
          {
            self.playerManager.jumpToChapter(nextChapter)
            NotificationCenter.default.post(name: .listeningProgressChanged, object: nil)
          } else {
            self.playerManager.playNextItem(autoPlayed: false, shouldAutoplay: true)
          }
          NotificationCenter.default.post(name: .listeningProgressChanged, object: nil)
        } label: {
          Image(systemName: hasNextChapter ? "chevron.right" : "chevron.right.2").tint(theme.primaryColor)
        }
          .accessibilityLabel("chapters_next_title".localized)
      }
    }
  }
}

#Preview {
  NavigationRowView(playerTitle: "Chapter 1")
}
