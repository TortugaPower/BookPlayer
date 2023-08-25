//
//  PricingRowView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 1/5/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct PricingRowView: View {
  @Binding var title: String
  @Binding var isSelected: Bool
  @Binding var isLoading: Bool
  /// Theme view model to update colors
  @EnvironmentObject var themeViewModel: ThemeViewModel
  
  var imageLength: CGFloat = 24
  
  var body: some View {
    if isLoading {
      ProgressView()
        .frame(maxWidth: .infinity)
        .padding([.top, .bottom])
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(themeViewModel.secondaryColor, lineWidth: 2)
        )
    } else if isSelected {
      HStack {
        Spacer()
          .frame(width: imageLength)
          .padding([.trailing], Spacing.S)
        Spacer()
        Text(title)
          .font(Font(Fonts.titleRegular))
          .foregroundColor(themeViewModel.linkColor)
        Spacer()
        Image(systemName: "checkmark.circle")
          .resizable()
          .frame(width: imageLength, height: imageLength)
          .foregroundColor(themeViewModel.linkColor)
          .padding([.trailing], Spacing.S)
      }
      .frame(maxWidth: .infinity)
      .padding([.top, .bottom])
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(themeViewModel.linkColor, lineWidth: 2)
      )
      .contentShape(Rectangle())
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isButton)
    } else {
      HStack {
        Spacer()
          .frame(width: imageLength)
          .padding([.trailing], Spacing.S)
        Spacer()
        Text(title)
          .font(Font(Fonts.titleRegular))
          .foregroundColor(themeViewModel.secondaryColor)
        Spacer()
        Image(systemName: "circle")
          .resizable()
          .frame(width: imageLength, height: imageLength)
          .foregroundColor(themeViewModel.secondaryColor)
          .padding([.trailing], Spacing.S)
      }
      .frame(maxWidth: .infinity)
      .padding([.top, .bottom])
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(themeViewModel.secondaryColor, lineWidth: 2)
      )
      .contentShape(Rectangle())
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isButton)
    }
  }
}

struct PricingRowView_Previews: PreviewProvider {
  static var previews: some View {
    VStack {
      PricingRowView(
        title: .constant("$4.99 per month"),
        isSelected: .constant(true),
        isLoading: .constant(false)
      )
      PricingRowView(
        title: .constant("$4.99 per month"),
        isSelected: .constant(false),
        isLoading: .constant(false)
      )
      PricingRowView(
        title: .constant("$4.99 per month"),
        isSelected: .constant(false),
        isLoading: .constant(true)
      )
    }
    .environmentObject(ThemeViewModel())
  }
}
