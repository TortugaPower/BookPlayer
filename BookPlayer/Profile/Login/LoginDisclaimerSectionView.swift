//
//  LoginDisclaimerSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct LoginDisclaimerSectionView: View {
  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    Section {
      VStack(alignment: .leading, spacing: 10) {
        Text("benefits_disclaimer_title")
          .bpFont(.title)
        Text("benefits_disclaimer_account_description")
          .bpFont(.body)
          .foregroundStyle(theme.secondaryColor)
        Text("benefits_disclaimer_subscription_description")
          .bpFont(.body)
          .foregroundStyle(theme.secondaryColor)
      }
    }
    .listRowBackground(Color.clear)
  }
}

#Preview {
  Form {
    LoginDisclaimerSectionView()
  }
  .environmentObject(ThemeViewModel())
}
