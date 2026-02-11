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

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    ThemedSection {
      HStack {
        Text("integration_server_name_label".localized)
          .foregroundStyle(theme.secondaryColor)
        Spacer()
        Text(serverName)
      }
      HStack {
        Text("integration_server_url_label".localized)
          .foregroundStyle(theme.secondaryColor)
        Spacer()
        Text(serverUrl)
      }
    } header: {
      Text("integration_section_server".localized)
        .foregroundStyle(theme.secondaryColor)
    }
  }
}
