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

  @Binding var account: Account?
  @EnvironmentObject var themeViewModel: ThemeViewModel

  var titleAccessibilityLabel: String {
    if let account,
       !account.email.isEmpty {
      return "account_title".localized
    } else {
      return "setup_account_title".localized
    }
  }

  var title: String {
    if let account,
       !account.email.isEmpty {
      return account.email
    } else {
      return "setup_account_title".localized
    }
  }

  var status: String? {
    if account == nil
        || account?.email.isEmpty == true {
      return "not_signedin_title".localized
    } else {
      return nil
    }
  }

  var body: some View {
    HStack(spacing: Spacing.S1) {
      ZStack {
        themeViewModel.tertiarySystemBackgroundColor
        Image(systemName: "person")
          .resizable()
          .frame(width: imageLength, height: imageLength)
          .foregroundStyle(themeViewModel.secondaryColor)
      }
      .frame(width: containerImageWidth, height: containerImageWidth)
      .clipShape(Circle())

      VStack(alignment: .leading) {
        Text(verbatim: title)
          .font(Font(Fonts.titleRegular))
          .foregroundStyle(themeViewModel.primaryColor)
        if let status {
          Text(status)
            .font(Font(Fonts.subheadline))
            .foregroundStyle(themeViewModel.secondaryColor)
        }
      }

      Spacer()
      Image(systemName: "chevron.forward")
        .foregroundStyle(themeViewModel.secondaryColor)
    }
    .frame(height: height)
    .padding([.leading, .trailing], Spacing.S)
    .background(themeViewModel.systemBackgroundColor)
    .cornerRadius(cornerRadius)
    .accessibilityElement()
    .accessibilityLabel(titleAccessibilityLabel)
    .accessibilityAddTraits(.isButton)
  }
}

struct ProfileCardView_Previews: PreviewProvider {
  static var previews: some View {
    ProfileCardView(account: .constant(Account()))
      .environmentObject(ThemeViewModel())
  }
}
