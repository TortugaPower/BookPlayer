//
//  SettingsIntegrationsSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct SettingsIntegrationsSectionView: View {
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Section {
      NavigationLink("Jellyfin", value: SettingsScreen.jellyfin)
      NavigationLink("AudiobookShelf", value: SettingsScreen.audiobookshelf)
      NavigationLink("Hardcover", value: SettingsScreen.hardcover)
    } header: {
      Text("integrations_title")
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

#Preview {
  NavigationStack {
    Form {
      SettingsIntegrationsSectionView()
    }
  }
  .environmentObject(ThemeViewModel())
}
