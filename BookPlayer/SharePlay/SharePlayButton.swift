//
//  SharePlayButton.swift
//  BookPlayer
//
//  Created by dawsonamf on 6/28/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import GroupActivities
import SwiftUI

struct SharePlayButton: View {
  @EnvironmentObject private var coordinator: SharePlayCoordinator
  @EnvironmentObject private var theme: ThemeViewModel

  let currentItem: PlayableItem

  @State private var showSharingSheet = false
  @State private var isStartingSession = false

  var body: some View {
    buttonContent
      .font(.title3)
      .sheet(isPresented: $showSharingSheet) {
        ActivitySharingView(activity: coordinator.makeActivity(for: currentItem))
      }
  }

  @ViewBuilder
  private var buttonContent: some View {
    if coordinator.isInSession {
      Menu {
        Button("shareplay_leave_title".localized) {
          coordinator.leaveSession()
        }
        Button("shareplay_end_title".localized, role: .destructive) {
          coordinator.endSession()
        }
      } label: {
        icon
      }
      .accessibilityLabel("voiceover_shareplay_active_title".localized)
    } else {
      Button {
        startSession()
      } label: {
        icon
      }
      .disabled(isStartingSession)
      .accessibilityLabel("voiceover_shareplay_start_title".localized)
    }
  }

  private var icon: some View {
    Image(systemName: "shareplay")
      .foregroundColor(coordinator.isInSession ? theme.linkColor : .white)
  }

  private func startSession() {
    guard !isStartingSession else { return }
    isStartingSession = true

    Task {
      if await coordinator.startSession(for: currentItem) == .needsSharingSheet {
        showSharingSheet = true
      }
      isStartingSession = false
    }
  }
}
