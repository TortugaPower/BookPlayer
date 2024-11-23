//
//  ProfileView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 11/11/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct ProfileView: View {
  @ForcedEnvironment(\.coreServices) var coreServices
  @Binding var account: Account?
  @State private var isLoading = false
  @State private var error: Error?

  var body: some View {
    VStack {
      Image(systemName: "person.crop.circle")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 45, height: 45)
      if let email = coreServices.accountService.getAccount()?.email {
        Text(verbatim: email)
      }
      Spacer()
      Button("logout_title".localized) {
        Task {
          do {
            isLoading = true
            try coreServices.accountService.logout()
            isLoading = false
            account = nil
            coreServices.hasSyncEnabled = false
          } catch {
            isLoading = false
            self.error = error
          }
        }
      }
      .buttonStyle(PlainButtonStyle())
      .foregroundStyle(.red)
    }
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
}
