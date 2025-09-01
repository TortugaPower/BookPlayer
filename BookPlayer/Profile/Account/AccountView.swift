//
//  AccountView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct AccountView: View {
  @State private var showDeleteAlert: Bool = false
  @State private var accountDeletedMessage: String = ""
  @State private var showAccountDeletedAlert: Bool = false
  @State private var showCompleteAccount: Bool = false
  @State private var loadingState = LoadingOverlayState()

  @Environment(\.accountService) private var accountService
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    Form {
      if accountService.account.hasSubscription {
        AccountManageProSectionView()
      } else {
        AccountPerksSectionView {
          showCompleteAccount = true
        }
      }
      AccountTermsConditionsSectionView()
      AccountLogoutSectionView()
      AccountDeleteSectionView(showAlert: $showDeleteAlert)
    }
    .navigationTitle(accountService.account.email)
    .navigationBarTitleDisplayMode(.inline)
    .applyListStyle(with: theme, background: theme.systemGroupedBackgroundColor)
    .errorAlert(error: $loadingState.error)
    .loadingOverlay(loadingState.show)
    .alert("Delete Account", isPresented: $showDeleteAlert) {
      Button("cancel_button", role: .cancel) {}
      Button("delete_button", role: .destructive) {
        Task {
          await deleteAccount()
        }
      }
    } message: {
      Text(
        "Warning: this action is not reversible, if your account is deleted, all your synced library details will be deleted from our servers"
      )
    }
    .alert(accountDeletedMessage, isPresented: $showAccountDeletedAlert) {
      Button("ok_button") {
        dismiss()
      }
    }
    .sheet(isPresented: $showCompleteAccount) {
      SettingsCompleteAccountView()
        .presentationDetents([.medium])
    }
  }

  func deleteAccount() async {
    loadingState.show = true

    do {
      let result = try await accountService.deleteAccount()
      loadingState.show = false
      accountDeletedMessage = result
      showAccountDeletedAlert = true
    } catch {
      loadingState.show = false
      loadingState.error = error
    }
  }
}

#Preview {
  NavigationStack {
    AccountView()
  }
  .environmentObject(ThemeViewModel())
}
