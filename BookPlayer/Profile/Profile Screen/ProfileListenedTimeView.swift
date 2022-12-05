//
//  ProfileListenedTimeView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 4/12/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI

protocol ProfileListenedTimeViewModel: ObservableObject {
  var totalListeningTimeFormatted: String { get set }
}

struct ProfileListenedTimeView<Model: ProfileListenedTimeViewModel>: View {
  @StateObject var themeViewModel = ThemeViewModel()
  @ObservedObject var viewModel: Model

  var body: some View {
    VStack {
      Text(viewModel.totalListeningTimeFormatted)
        .font(Font(Fonts.title))
        .foregroundColor(themeViewModel.primaryColor)
      Text("Total Listening Time")
        .font(Font(Fonts.subheadline))
        .foregroundColor(themeViewModel.secondaryColor)
    }
    .padding(.top, Spacing.S1)
  }
}

struct ProfileStatsView_Previews: PreviewProvider {
  class MockProfileStatsViewModel: ProfileListenedTimeViewModel, ObservableObject {
    var totalListeningTimeFormatted: String = "0m"
  }
  static var previews: some View {
    ProfileListenedTimeView(viewModel: MockProfileStatsViewModel())
  }
}
