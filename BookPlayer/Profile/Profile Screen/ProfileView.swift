//
//  ProfileView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 17/1/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ProfileView<Model: ProfileViewModelProtocol>: View {
  @StateObject var themeViewModel = ThemeViewModel()
  @ObservedObject var viewModel: Model

  var body: some View {
    VStack(spacing: Spacing.M) {
      ProfileCardView(account: $viewModel.account)
        .onTapGesture {
          viewModel.showAccount()
        }
        .padding([.top, .trailing, .leading], Spacing.S)

      ProfileListenedTimeView(
        formattedListeningTime: $viewModel.totalListeningTimeFormatted
      )

      Spacer()

      if viewModel.account?.hasSubscription == true,
        viewModel.account?.id.isEmpty == false
      {
        ProfileSyncTasksStatusView(
          buttonText: $viewModel.tasksButtonText,
          statusMessage: $viewModel.refreshStatusMessage,
          themeViewModel: themeViewModel,
          showTasksAction: {
            viewModel.showTasks()
          }
        )
        .padding([.trailing, .leading], Spacing.M)
      } else if viewModel.account?.hasSubscription == false, viewModel.account?.id.isEmpty == true {
        VStack {
          Text("BookPlayer Pro")
            .font(Font(Fonts.title))
            .foregroundColor(themeViewModel.primaryColor)
          Button(
            action: {
              viewModel.showAccount()
            },
            label: {
              Text("learn_more_title".localized)
                .font(.system(size: 11, weight: .bold))
                .frame(minWidth: 92, minHeight: 22)
                .background(themeViewModel.linkColor)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
          )
        }
      }
    }
    .padding([.bottom], viewModel.bottomOffset)
    .environmentObject(themeViewModel)
  }
}

struct ProfileView_Previews: PreviewProvider {
  class MockProfileViewModel: ProfileViewModelProtocol, ObservableObject {
    var tasksButtonText: String = "Queued sync tasks"
    var bottomOffset: CGFloat = Spacing.M
    var refreshStatusMessage: String = "Last refresh: 1 second ago"
    var totalListeningTimeFormatted: String = "0m"
    var account: Account?

    func showAccount() {}
    func showTasks() {}
  }
  static var previews: some View {
    ProfileView(viewModel: MockProfileViewModel())
      .previewLayout(.sizeThatFits)
  }
}
