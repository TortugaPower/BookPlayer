//
//  SettingsView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 11/11/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import AuthenticationServices
import BookPlayerWatchKit
import SwiftUI

struct SettingsView: View {
  @AppStorage("userEmail")
  var email: String?

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        Group {
          if email != nil {
            ProfileView()
          } else {
            LoginView()
              .fixedSize(horizontal: false, vertical: true)
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
