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
  
  var playerTitle: String
  
  var body: some View {
    HStack {
      HStack(spacing: 16) {
        Button {
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          self.playerManager.playNextItem(autoPlayed: false, shouldAutoplay: true)
        } label: {
          Image(systemName: "chevron.left.2")
        }
        Button {
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          if let currentChapter = self.playerManager.currentItem?.currentChapter,
            let nextChapter = self.playerManager.currentItem?.nextChapter(after: currentChapter)
          {
            self.playerManager.jumpToChapter(nextChapter)
            //sendEvent(.updateProgress(getCurrentProgressState()))
          }
        } label: {
          Image(systemName: "chevron.left")
        }
      }
      
      Spacer()
      
      Text(playerTitle)
        .bpFont(.headline)
        .multilineTextAlignment(.center)
        .frame(height: 100)
      
      Spacer()
      
      HStack(spacing: 16) {
        Button {
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()

          if let currentChapter = self.playerManager.currentItem?.currentChapter,
            let previousChapter = self.playerManager.currentItem?.previousChapter(before: currentChapter)
          {
            self.playerManager.jumpToChapter(previousChapter)
            //sendEvent(.updateProgress(getCurrentProgressState()))
          }
        } label: {
          Image(systemName: "chevron.right")
        }
        Button {
          self.playerManager.playNextItem(autoPlayed: false, shouldAutoplay: true)
        } label: {
          Image(systemName: "chevron.right.2")
        }
      }
    }
  }
}

#Preview {
  NavigationRowView(playerTitle: "Chapter 1")
}
