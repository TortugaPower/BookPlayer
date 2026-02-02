//
//  AccountTermsConditionsSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct AccountTermsConditionsSectionView: View {
  @Environment(\.openURL) private var openURL
  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    Section {
      Button {
        let url = URL(string: "https://github.com/TortugaPower/BookPlayer/blob/main/TERMS_CONDITIONS.md")!
        openURL(url)
      } label: {
        Label {
          Text("terms_conditions_title")
            .bpFont(.body)
            .foregroundStyle(theme.primaryColor)
        } icon: {
          Image(systemName: "doc.text")
            .foregroundStyle(theme.linkColor)
        }
      }

      Button {
        let url = URL(string: "https://github.com/TortugaPower/BookPlayer/blob/main/PRIVACY_POLICY.md")!
        openURL(url)
      } label: {
        Label {
          Text("privacy_policy_title")
            .bpFont(.body)
            .foregroundStyle(theme.primaryColor)
        } icon: {
          Image(systemName: "doc.text")
            .foregroundStyle(theme.linkColor)
        }
      }
    }
  }
}

#Preview {
  AccountTermsConditionsSectionView()
    .environmentObject(ThemeViewModel())
}
