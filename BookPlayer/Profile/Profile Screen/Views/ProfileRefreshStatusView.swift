//
//  ProfileRefreshStatusView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/1/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import SwiftUI

struct ProfileRefreshStatusView: View {

  @Binding var statusMessage: String
  @ObservedObject var themeViewModel: ThemeViewModel

  var refreshAction: () -> Void

  var body: some View {
    VStack {
      Button("Sync Library", action: refreshAction)
        .foregroundColor(themeViewModel.linkColor)
      Text(statusMessage)
        .foregroundColor(themeViewModel.secondaryColor)
    }
  }
}

struct ProfileRefreshStatusView_Previews: PreviewProvider {
  static var previews: some View {
    ProfileRefreshStatusView(
      statusMessage: .constant("Last sync: 1 second ago"),
      themeViewModel: ThemeViewModel(),
      refreshAction: {}
    )
  }
}
