//
//  ProfileCardView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 17/1/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ProfileCardView: View {
  let containerImageWidth: CGFloat = 40
  let imageLength: CGFloat = 20
  var height: CGFloat = 70
  var cornerRadius: CGFloat = 10

  @Binding var account: Account?
  @ObservedObject var themeViewModel: ThemeViewModel

  var title: String {
    if let account,
       !account.email.isEmpty {
      return account.email
    } else {
      return "Set Up Account"
    }
  }

  var status: String? {
    if account == nil
        || account?.email.isEmpty == true {
      return "Not signed in"
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
          .foregroundColor(themeViewModel.secondaryColor)
      }
      .frame(width: containerImageWidth, height: containerImageWidth)
      .clipShape(Circle())

      VStack(alignment: .leading) {
        Text(verbatim: title)
          .font(Font(Fonts.titleRegular))
          .foregroundColor(themeViewModel.primaryColor)
        if let status {
          Text(status)
            .font(Font(Fonts.subheadline))
            .foregroundColor(themeViewModel.secondaryColor)
        }
      }

      Spacer()
      Image(systemName: "chevron.forward")
        .foregroundColor(themeViewModel.secondaryColor)
    }
    .frame(height: height)
    .padding([.leading, .trailing], Spacing.S)
    .background(themeViewModel.systemBackgroundColor)
    .cornerRadius(cornerRadius)
  }
}

struct ProfileCardView_Previews: PreviewProvider {
  static var previews: some View {
    ProfileCardView(
      account: .constant(Account()),
      themeViewModel: ThemeViewModel()
    )
  }
}
