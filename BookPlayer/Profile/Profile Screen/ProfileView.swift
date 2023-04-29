//
//  ProfileView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 17/1/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ProfileView<Model: ProfileViewModelProtocol>: View {
  @StateObject var themeViewModel = ThemeViewModel()
  @ObservedObject var viewModel: Model

  var body: some View {
    GeometryReader { geometryProxy in
      ScrollView {
        VStack(spacing: Spacing.M) {
          ProfileCardView(
            account: $viewModel.account,
            themeViewModel: themeViewModel
          )
          .onTapGesture {
            viewModel.showAccount()
          }
          .padding([.top, .trailing, .leading], Spacing.S)

          ProfileListenedTimeView(
            formattedListeningTime: $viewModel.totalListeningTimeFormatted,
            themeViewModel: themeViewModel
          )

          Spacer()

          if viewModel.account?.hasSubscription == true {
            ProfileRefreshStatusView(
              statusMessage: $viewModel.refreshStatusMessage,
              buttonDisabled: $viewModel.isSyncButtonDisabled,
              themeViewModel: themeViewModel,
              refreshAction: {
                viewModel.syncLibrary()
              }
            )
            .padding([.trailing, .leading], Spacing.M)
            .padding([.bottom], viewModel.bottomOffset)
          }
        }
        .frame(maxWidth: .infinity, minHeight: geometryProxy.size.height)
      }
    }
  }
}

struct ProfileView_Previews: PreviewProvider {
  class MockProfileViewModel: ProfileViewModelProtocol, ObservableObject {
    var isSyncButtonDisabled: Bool = false
    var bottomOffset: CGFloat = Spacing.M
    var refreshStatusMessage: String = "Last refresh: 1 second ago"
    var totalListeningTimeFormatted: String = "0m"
    var account: Account?

    func showAccount() {}
    func syncLibrary() {}
  }
  static var previews: some View {
    ProfileView(viewModel: MockProfileViewModel())
      .previewLayout(.sizeThatFits)
  }
}
