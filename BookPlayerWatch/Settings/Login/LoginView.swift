//
//  LoginView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 11/11/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct LoginView: View {
  @ForcedEnvironment(\.coreServices) var coreServices
  @Binding var account: Account?
  @State private var isLoading = false
  @State private var error: Error?

  var body: some View {
    List {
      Text("BookPlayer Pro")
        .font(Font(Fonts.titleLarge))
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .listRowBackground(Color.clear)
      Text("benefits_watchapp_description".localized)
        .font(Font(Fonts.body))
        .multilineTextAlignment(.center)
        .listRowBackground(Color.clear)
      Spacer(minLength: Spacing.S2)
        .listRowBackground(Color.clear)

      Button {
        signInWithiPhone()
      } label: {
        HStack {
          Image(systemName: "iphone")
          Text("watch_signin_with_iphone".localized)
        }
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .buttonBorderShape(.roundedRectangle)
      .listRowBackground(Color.clear)
      Spacer(minLength: Spacing.M)
        .listRowBackground(Color.clear)
    }
    .environment(\.defaultMinListRowHeight, 1)
    .errorAlert(error: $error)
    .overlay {
      Group {
        if isLoading {
          ProgressView()
            .tint(.white)
            .padding()
            .background(
              Color.black
                .opacity(0.9)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            )
        }
      }
    }
  }

  private func signInWithiPhone() {
    Task {
      do {
        isLoading = true

        let authResponse = try await coreServices.watchConnectivityService.requestAuthFromiPhone()

        let account = try await coreServices.accountService.loginWithTransferredCredentials(
          token: authResponse.token,
          accountId: authResponse.accountId,
          email: authResponse.email,
          hasSubscription: authResponse.hasSubscription,
          donationMade: authResponse.donationMade
        )

        isLoading = false
        self.account = account
        coreServices.checkAndReloadIfSyncIsEnabled()
      } catch {
        isLoading = false
        self.error = error
      }
    }
  }
}
