//
//  IntegrationServerInformationSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct IntegrationServerInformationSectionView: View {
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
