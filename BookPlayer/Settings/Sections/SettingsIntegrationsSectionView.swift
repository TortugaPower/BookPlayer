//
//  SettingsIntegrationsSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct SettingsIntegrationsSectionView: View {
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    ThemedSection {
      NavigationLink(value: SettingsScreen.mediaServers) {
        Text("media_servers_title")
          .bpFont(.body)
      }
      NavigationLink(value: SettingsScreen.hardcover) {
        Text("Hardcover")
          .bpFont(.body)
      }
    } header: {
      Text("integrations_title")
        .bpFont(.subheadline)
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
