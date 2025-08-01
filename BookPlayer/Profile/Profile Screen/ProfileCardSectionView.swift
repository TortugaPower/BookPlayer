//
//  ProfileCardSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 31/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ProfileCardSectionView: View {
  @Environment(\.accountService) private var accountService

  var destination: ProfileScreen {
    accountService.account.id.isEmpty
      ? .login
      : .account
  }

  var body: some View {
    Section {
      NavigationLink(value: destination) {
        ProfileCardView(email: accountService.account.email)
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

  Form {
    ProfileCardSectionView()
  }
  .environmentObject(ThemeViewModel())
  .environment(\.accountService, accountService)
}
