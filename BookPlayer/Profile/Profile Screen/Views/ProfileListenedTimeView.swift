//
//  ProfileListenedTimeView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 4/12/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ProfileListenedTimeView: View {
  @Binding var formattedListeningTime: String
  @EnvironmentObject var themeViewModel: ThemeViewModel

  var body: some View {
    VStack {
      Text(formattedListeningTime)
        .font(Font(Fonts.title))
        .foregroundColor(themeViewModel.primaryColor)
      Text("total_listening_title".localized)
        .font(Font(Fonts.subheadline))
        .foregroundColor(themeViewModel.secondaryColor)
    }
  }
}

struct ProfileStatsView_Previews: PreviewProvider {
  static var previews: some View {
    ProfileListenedTimeView(
      formattedListeningTime: .constant("0m")
    )
  }
}
