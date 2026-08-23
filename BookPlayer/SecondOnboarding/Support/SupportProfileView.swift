//
//  SupportProfileView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/7/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
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
              .foregroundStyle(themeViewModel.linkColor)
          })
          Spacer()
        }
        .frame(height: 56)
        .accessibilityHidden(true)
        Spacer()
        Image(systemName: "person.crop.circle")
          .resizable()
          .foregroundStyle(themeViewModel.secondaryColor.opacity(0.5))
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: 150)
          .padding([.bottom], Spacing.M)
          .accessibilityHidden(true)
        
        Group {
          Text("create_profile_title".localized)
            .bpFont(.titleStory)
            .foregroundStyle(themeViewModel.primaryColor)
            .padding()
          Text("create_profile_description".localized)
            .bpFont(.bodyStory)
            .foregroundStyle(themeViewModel.primaryColor)
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
          Text("not_now_button".localized)
            .underline()
            .bpFont(.body)
            .foregroundStyle(themeViewModel.secondaryColor)
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
