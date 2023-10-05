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
  let title: String
  var height: CGFloat = 24

  let isSelected: Bool
  let isLoading: Bool

  @EnvironmentObject
  var themeViewModel: ThemeViewModel

  var body: some View {
    ZStack {
      ProgressView().opacity(isLoading ? 1 : 0)
      LoadedButton(title: title,
                   imageWidth: height,
                   isSelected: isSelected)
      .opacity(isLoading ? 0 : 1)
    }
    .foregroundColor(primeColor)
    .frame(height: height)
    .frame(maxWidth: .infinity)
    .padding([.top, .bottom])
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(primeColor, lineWidth: 2))
    .animation(.easeIn)
  }

  var primeColor: Color {
    switch (isLoading, isSelected) {
    case (false, true):
      themeViewModel.linkColor
    default:
      themeViewModel.secondaryColor
    }
  }
}

struct PricingRowView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      VStack {
        PricingRowView(title: "$4.99 per month",
                       isSelected: true,
                       isLoading: false)
        PricingRowView(title: "$4.99 per month",
                       isSelected: true,
                       isLoading: true)
        PricingRowView(title: "$4.99 per month",
                       isSelected: false,
                       isLoading: false)
        PricingRowView(title: "$4.99 per month",
                       isSelected: false,
                       isLoading: true)
      }
      .previewDisplayName("Static Preview")

      RowWrapper()
        .previewDisplayName("Animation Preview")
    }
    .padding()
    .environmentObject(ThemeViewModel())
    .previewLayout(.sizeThatFits)
  }

  private struct RowWrapper: View {
    @State var isSelected: Bool = false
    @State var isLoading: Bool = false

    var body: some View {
      VStack {
        PricingRowView(title: "$4.99 per month",
                       isSelected: isSelected,
                       isLoading: isLoading)
        Toggle(isOn: $isSelected) {
          Text("Selected")
        }
        Toggle(isOn: $isLoading) {
          Text("Loading")
        }
      }
      .onTapGesture(perform: isLoading
                    ? {}
                    : { isSelected = true })
    }
  }
}

private struct LoadedButton: View {
  let title: String
  let imageWidth: CGFloat

  let isSelected: Bool

  var body: some View {
    HStack {
      Spacer()
        .frame(width: imageWidth)
        .padding([.trailing], Spacing.S)
      Spacer()
      Text(title)
        .font(Font(Fonts.titleRegular))
      Spacer()
      Image(systemName: isSelected ? "checkmark.circle" : "circle")
        .resizable()
        .frame(width: imageWidth)
        .padding([.trailing], Spacing.S)
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
  }
}
