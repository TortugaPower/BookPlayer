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
  @EnvironmentObject private var theme: ThemeViewModel
  
  var action: () -> Void

  var body: some View {
    Section {
      Button(action: action) {
        ProfileCardView(email: accountService.account.email)
      }
    }
    .listRowBackground(theme.tertiarySystemBackgroundColor)
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
    ProfileCardSectionView {}
  }
  .environmentObject(ThemeViewModel())
  .environment(\.accountService, accountService)
}
