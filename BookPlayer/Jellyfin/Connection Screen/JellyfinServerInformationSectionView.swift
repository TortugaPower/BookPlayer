//
//  JellyfinServerInformationSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 6/6/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct JellyfinServerInformationSectionView: View {
  let serverName: String
  let serverUrl: String

  @EnvironmentObject var themeViewModel: ThemeViewModel

  var body: some View {
    Section {
      HStack {
        Text("jellyfin_server_name_label".localized)
          .foregroundColor(themeViewModel.secondaryColor)
        Spacer()
        Text(serverName)
      }
      HStack {
        Text("jellyfin_server_url_label".localized)
          .foregroundColor(themeViewModel.secondaryColor)
        Spacer()
        Text(serverUrl)
      }
    } header: {
      Text("jellyfin_section_server".localized)
    }
    .listRowBackground(themeViewModel.secondarySystemBackgroundColor)
  }
}
