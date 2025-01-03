//
//  SettingsView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 11/11/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import AuthenticationServices
import BookPlayerWatchKit
import SwiftUI

struct SettingsView: View {
  @ForcedEnvironment(\.coreServices) var coreServices
  @State var account: Account?

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        Group {
          if account?.id != nil,
            account?.id.isEmpty == false
          {
            ProfileView(account: $account)
          } else {
            LoginView(account: $account)
          }
        }
        .padding(.horizontal, Spacing.S3)
        .frame(width: geometry.size.width, height: geometry.size.height)
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
  }
}

#Preview {
  SettingsView()
}
