//
//  ProfileSyncTasksStatusView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/1/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct ProfileSyncTasksStatusView: View {
  @Binding var buttonText: String
  @Binding var statusMessage: String
  @ObservedObject var themeViewModel: ThemeViewModel

  var showTasksAction: () -> Void

  var body: some View {
    VStack {
      Button(buttonText, action: showTasksAction)
        .foregroundColor(themeViewModel.linkColor)
      Text(statusMessage)
        .foregroundColor(themeViewModel.secondaryColor)
    }
  }
}

struct ProfileRefreshStatusView_Previews: PreviewProvider {
  static var previews: some View {
    ProfileSyncTasksStatusView(
      buttonText: .constant("Queued sync tasks"),
      statusMessage: .constant("Last sync: 1 second ago"),
      themeViewModel: ThemeViewModel(),
      showTasksAction: {}
    )
  }
}
