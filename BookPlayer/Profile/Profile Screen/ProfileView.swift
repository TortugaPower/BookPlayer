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
  @StateObject private var theme = ThemeViewModel()
  @Environment(\.accountService) private var accountService
  @Environment(\.playerState) private var playerState

  var body: some View {
    NavigationStack(path: $path) {
      VStack(spacing: 0) {
        Form {
          ProfileCardSectionView()
            .listSectionSpacing(Spacing.S1)
          ProfileListenedSectionView()
        }

        Spacer()

        if accountService.account.hasSubscription,
          !accountService.account.id.isEmpty
        {
          ProfileSyncTasksSectionView()
        } else if !accountService.account.hasSubscription {
          ProfileProCalloutSectionView()
        }
      }
      .safeAreaInset(edge: .bottom) {
        Spacer().frame(height: playerState.isBookLoaded ? 96 : Spacing.M)
      }
      .navigationTitle("profile_title")
      .navigationBarTitleDisplayMode(.inline)
      .scrollContentBackground(.hidden)
      .background(theme.systemGroupedBackgroundColor)
      .listRowBackground(theme.secondarySystemBackgroundColor)
      .toolbarColorScheme(theme.useDarkVariant ? .dark : .light, for: .navigationBar)
      .navigationDestination(for: ProfileScreen.self) { destination in
        switch destination {
        case .account:
          EmptyView()
        case .login:
          Text("login")
        case .tasks:
          EmptyView()
        }
      }
    }
    .foregroundStyle(theme.primaryColor)
    .tint(theme.linkColor)
    .environmentObject(theme)
  }
}
