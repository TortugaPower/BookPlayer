//
//  ProfileCardView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 17/1/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ProfileCardView: View {
  let containerImageWidth: CGFloat = 40
  let imageLength: CGFloat = 20
  var height: CGFloat = 70
  var cornerRadius: CGFloat = 10

  var email: String = ""
  @EnvironmentObject var theme: ThemeViewModel

  var titleAccessibilityLabel: String {
    if !email.isEmpty {
      return "account_title".localized
    } else {
      return "setup_account_title".localized
    }
  }

  var title: String {
    if !email.isEmpty {
      return email
    } else {
      return "setup_account_title".localized
    }
  }

  var status: String? {
    if email.isEmpty {
      return "not_signedin_title".localized
    } else {
      return nil
    }
  }

  var body: some View {
    HStack(spacing: Spacing.S1) {
      ZStack {
        theme.tertiarySystemBackgroundColor
        Image(systemName: "person")
          .resizable()
          .frame(width: imageLength, height: imageLength)
          .foregroundStyle(theme.secondaryColor)
      }
      .frame(width: containerImageWidth, height: containerImageWidth)
      .clipShape(Circle())

      VStack(alignment: .leading) {
        Text(verbatim: title)
          .font(Font(Fonts.titleRegular))
        if let status {
          Text(status)
            .font(Font(Fonts.subheadline))
            .foregroundStyle(theme.secondaryColor)
        }
      }

      Spacer()

      Image(systemName: "chevron.forward")
        .foregroundStyle(theme.secondaryColor)
    }
    .accessibilityElement()
    .accessibilityLabel(titleAccessibilityLabel)
    .accessibilityAddTraits(.isButton)
  }
}
