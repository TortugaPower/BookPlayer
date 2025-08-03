//
//  LoginBenefitSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct LoginBenefitSectionView: View {
  let imageName: String
  let title: LocalizedStringKey
  let subtitle: LocalizedStringKey

  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    Section {
      HStack {
        Image(systemName: imageName)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 45, height: 45)
          .opacity(0.5)
          .foregroundStyle(theme.linkColor)
          .padding(.trailing, 23)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 10) {
          Text(title)
            .bpFont(Fonts.title)
          Text(subtitle)
            .bpFont(Fonts.body)
            .foregroundStyle(theme.secondaryColor)
        }
        .accessibilityElement(children: .combine)
      }
    }
    .listRowBackground(Color.clear)
  }
}

#Preview {
  Form {
    LoginBenefitSectionView(
      imageName: "paintpalette.fill",
      title: "benefits_themesicons_title",
      subtitle: "benefits_themesicons_description"
    )
  }
  .environmentObject(ThemeViewModel())
}
