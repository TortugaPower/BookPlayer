//
//  ProfileProCalloutSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 31/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ProfileProCalloutSectionView: View {
  @Environment(\.accountService) private var accountService
  @EnvironmentObject private var theme: ThemeViewModel

  var destination: ProfileScreen {
    accountService.account.id.isEmpty
      ? .login
      : .account
  }

  var body: some View {
    NavigationLink(value: destination) {
      VStack {
        Text("BookPlayer Pro")
          .font(Font(Fonts.title))
        Text("learn_more_title".localized)
          .bpFont(Fonts.buttonTextSmall)
          .padding(.horizontal, Spacing.S)
          .padding(.vertical, Spacing.S3)
          .background(theme.linkColor)
          .foregroundStyle(.white)
          .clipShape(Capsule())
      }
    }
  }
}

#Preview {
  @Previewable var accountService: AccountService = {
    let accountService = AccountService()
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: ""))
    accountService.setup(dataManager: dataManager)
    accountService.accessLevel = .free

    return accountService
  }()

  ProfileProCalloutSectionView()
    .environmentObject(ThemeViewModel())
    .environment(\.accountService, accountService)
}
