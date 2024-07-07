//
//  SupportProfileView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/7/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import AuthenticationServices
import BookPlayerKit
import SwiftUI

struct SupportProfileView<Model: LoginViewModelProtocol>: View {
  @StateObject var themeViewModel = ThemeViewModel()
  @ObservedObject var viewModel: Model

  var body: some View {
    ZStack {
      themeViewModel.systemBackgroundColor
        .ignoresSafeArea()
      VStack {
        HStack {
          Button(action: {
            viewModel.dismiss()
          }, label: {
            Image(systemName: "xmark")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 23)
              .foregroundColor(themeViewModel.linkColor)
          })
          Spacer()
        }
        .frame(height: 56)
        .accessibilityHidden(true)
        Spacer()
        Image(systemName: "person.crop.circle")
          .resizable()
          .foregroundColor(themeViewModel.secondaryColor.opacity(0.5))
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: 150)
          .padding([.bottom], Spacing.M)
          .accessibilityHidden(true)
        
        Group {
          Text("Create your profile")
            .font(Font(Fonts.titleStory))
            .foregroundColor(themeViewModel.primaryColor)
            .padding()
          Text("To enable cloud sync, sign into your profile. You can always do this later from within the Profile tab")
            .font(Font(Fonts.bodyStory))
            .foregroundColor(themeViewModel.primaryColor)
            .multilineTextAlignment(.center)
        }
        .padding([.bottom], Spacing.M)

        Spacer()
        SignInWithAppleButton { request in
          request.requestedScopes = [.email]
        } onCompletion: { result in
          switch result {
          case .success(let authorization):
            viewModel.handleSignIn(authorization: authorization)
          default:
            break
          }
        }
        .signInWithAppleButtonStyle(themeViewModel.useDarkVariant ? .white : .black)
        .frame(height: 45)
        Button(action: {
          viewModel.dismiss()
        }, label: {
          Text("Not now")
            .underline()
            .font(Font(Fonts.body))
            .foregroundColor(themeViewModel.secondaryColor)
        })
        .padding([.top], Spacing.S5)
      }
      .padding([.horizontal], Spacing.M)
    }
  }
}

private class MockLoginViewModelProtocol: LoginViewModelProtocol {
  func handleSignIn(authorization: ASAuthorization) {
    print("Sign in")
  }

  func dismiss() {}
}

#Preview {
  SupportProfileView(viewModel: MockLoginViewModelProtocol())
}
