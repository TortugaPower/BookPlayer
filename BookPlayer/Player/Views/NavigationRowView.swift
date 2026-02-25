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
  var onTitleToggle: (() -> Void)?
  
  var body: some View {
    HStack(spacing: 4) {
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
        Image(systemName: hasPreviousChapter ? "chevron.left" : "chevron.left.2")
          .bpFont(.playerTitle)
          .tint(theme.primaryColor)
          .frame(height: 56)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .accessibilityLabel("chapters_previous_title".localized)
      
      Spacer()
      
      Button {
        onTitleToggle?()
      } label: {
        Text(playerTitle)
          .bpFont(.playerTitle)
          .foregroundColor(theme.primaryColor)
          .multilineTextAlignment(.center)
          .frame(height: 56)
      }
      .layoutPriority(1)
      
      Spacer()
      
      Button {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if let currentChapter = self.playerManager.currentItem?.currentChapter,
          let nextChapter = self.playerManager.currentItem?.nextChapter(after: currentChapter)
        {
          self.playerManager.jumpToChapter(nextChapter)
        } else {
          self.playerManager.playNextItem(autoPlayed: false, shouldAutoplay: true)
        }
        NotificationCenter.default.post(name: .listeningProgressChanged, object: nil)
      } label: {
        Image(systemName: hasNextChapter ? "chevron.right" : "chevron.right.2")
          .bpFont(.playerTitle)
          .tint(theme.primaryColor)
          .frame(height: 56)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .accessibilityLabel("chapters_next_title".localized)
    }
  }
}

#Preview {
  NavigationRowView(playerTitle: "Chapter 1")
}
