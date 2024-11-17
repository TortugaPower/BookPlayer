//
//  LoginView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 11/11/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import AuthenticationServices
import BookPlayerWatchKit
import SwiftUI

struct LoginView: View {
  @StateObject var model = LoginViewModel()
  @State private var isLoading = false
  @State private var error: Error?
  @Environment(\.dismiss) var dismiss

  var body: some View {
    VStack(spacing: Spacing.S1) {
      Text("BookPlayer Pro")
        .font(Font(Fonts.titleLarge))
      Text("Stream your recent books to your Apple Watch, or download them to listen offline on the go.")
        .font(Font(Fonts.body))
        .multilineTextAlignment(.center)
      SignInWithAppleButton(.signIn) { request in
        request.requestedScopes = [.email]
      } onCompletion: { result in
        switch result {
        case .success(let authorization):
          Task {
            do {
              isLoading = true
              try await model.handleSignIn(authorization)
              isLoading = false
            } catch {
              isLoading = false
              self.error = error
            }
          }
        case .failure(let error):
          self.error = error
        }
      }
      .frame(maxHeight: 45)
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

#Preview {
  LoginView()
}
