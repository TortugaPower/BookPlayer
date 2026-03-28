//
//  ProfileView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 17/1/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ProfileView: View {
  @State private var path = NavigationPath()
  @State private var showLogin = false
  @Environment(\.accountService) private var accountService
  @Environment(\.concurrenceService) private var concurrenceService
  @Environment(\.playerState) private var playerState
  @EnvironmentObject private var theme: ThemeViewModel

  @State private var jobsCount: Int = 0
  
  var body: some View {
    NavigationStack(path: $path) {
      VStack(spacing: 0) {
        Form {
          ProfileCardSectionView(action: showLoginOrAccount)
            .listSectionSpacing(Spacing.S1)
          ProfileListenedSectionView()
        }

        Spacer()
        
        NavigationLink(value: ProfileScreen.concurrentTasks) {
          VStack {
            Text("Concurrent Tasks: \(jobsCount)")
              .bpFont(.body)
              .foregroundStyle(theme.linkColor)
          }
        }
        .padding(.bottom, Spacing.L1)
        .onReceive(concurrenceService.observeConcurrentTasksCount()) { count in
          guard jobsCount != count else { return }

          jobsCount = count
        }

        if accountService.account.hasSubscription,
          !accountService.account.id.isEmpty
        {
          ProfileSyncTasksSectionView()
        } else if !accountService.account.hasSubscription {
          ProfileProCalloutSectionView(action: showLoginOrAccount)
        }
      }
      .miniPlayerSafeAreaInset()
      .applyListStyle(with: theme, background: theme.systemBackgroundColor)
      .navigationTitle("profile_title")
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(for: ProfileScreen.self) { destination in
        switch destination {
        case .account:
          AccountView()
        case .tasks:
          QueuedSyncTasksView()
            .miniPlayerSafeAreaInset()
        case .concurrentTasks:
          ConcurrentSyncTasksView()
            .miniPlayerSafeAreaInset()
        }
      }
      .sheet(isPresented: $showLogin) {
        NavigationStack {
          LoginView()
        }
      }
    }
    .foregroundStyle(theme.primaryColor)
    .tint(theme.linkColor)
  }

  func showLoginOrAccount() {
    if accountService.account.id.isEmpty {
      showLogin = true
    } else {
      path.append(ProfileScreen.account)
    }
  }
}
