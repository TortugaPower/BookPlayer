//
//  AudiobookShelfServerInformationSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct AudiobookShelfServerInformationSectionView: View {
  let serverName: String
  let serverUrl: String

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Section {
      HStack {
        Text("integration_server_name_label")
          .foregroundStyle(theme.secondaryColor)
        Spacer()
        Text(serverName)
      }
      HStack {
        Text("integration_server_url_label")
          .foregroundStyle(theme.secondaryColor)
        Spacer()
        Text(serverUrl)
      }
    } header: {
      Text("integration_section_server")
        .foregroundStyle(theme.secondaryColor)
    }
  }
}
