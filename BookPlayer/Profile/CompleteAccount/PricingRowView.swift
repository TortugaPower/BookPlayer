//
//  PricingRowView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 1/5/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import RevenueCat
import SwiftUI

struct PricingRowView: View {
  let title: String
  let isSelected: Bool
  let isLoading: Bool

  @EnvironmentObject var theme: ThemeViewModel

  var imageLength: CGFloat = 24

  var body: some View {
    if isLoading {
      ProgressView()
        .frame(maxWidth: .infinity)
        .padding([.top, .bottom])
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(theme.secondaryColor, lineWidth: 2)
        )
    } else {
      HStack {
        Spacer()
          .frame(width: imageLength)
          .padding([.trailing], Spacing.S)
        Spacer()
        Text(title)
          .bpFont(Fonts.titleRegular)
          .foregroundStyle(color)
        Spacer()
        Image(systemName: isSelected ? "checkmark.circle" : "circle")
          .resizable()
          .frame(width: imageLength, height: imageLength)
          .foregroundStyle(color)
          .padding([.trailing], Spacing.S)
      }
      .frame(maxWidth: .infinity)
      .padding([.top, .bottom])
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(color, lineWidth: 2)
      )
      .contentShape(Rectangle())
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isButton)
    }
  }

  var color: Color {
    isSelected ? theme.linkColor : theme.secondaryColor
  }
}
