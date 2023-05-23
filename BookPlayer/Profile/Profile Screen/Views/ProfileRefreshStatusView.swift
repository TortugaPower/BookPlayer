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
  @Binding var buttonDisabled: Bool
  @ObservedObject var themeViewModel: ThemeViewModel

  var refreshAction: () -> Void

  var body: some View {
    VStack {
      /// Disabled showing the sync button
      if false {
        Button("sync_library_title".localized, action: refreshAction)
          .foregroundColor(themeViewModel.linkColor)
          .opacity(buttonDisabled ? 0.5 : 1)
          .disabled(buttonDisabled)
      }
      Text(statusMessage)
        .foregroundColor(themeViewModel.secondaryColor)
    }
  }
}

struct ProfileRefreshStatusView_Previews: PreviewProvider {
  static var previews: some View {
    ProfileRefreshStatusView(
      statusMessage: .constant("Last sync: 1 second ago"),
      buttonDisabled: .constant(true),
      themeViewModel: ThemeViewModel(),
      refreshAction: {}
    )
  }
}
