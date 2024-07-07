//
//  PricingBoxView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/6/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct PricingBoxView: View {
  @Binding var title: String
  @Binding var isSelected: Bool

  var imageLength: CGFloat = 16
  var imageName: String {
    isSelected ? "checkmark.circle" : "circle"
  }
  var foregroundColor: Color {
    isSelected 
    ? Color(UIColor(hex: "3488D1"))
    : Color(UIColor(hex: "334046"))
  }
  var backgroundColor: Color {
    isSelected
    ? Color.white
    : Color(UIColor(hex: "F8F8F8"))
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Spacer()
        Image(systemName: imageName)
          .resizable()
          .frame(width: imageLength, height: imageLength)
          .foregroundColor(foregroundColor)
          .padding([.trailing, .top], Spacing.S3)
      }
      Text(title)
        .font(Font(Fonts.titleLarge))
        .foregroundColor(foregroundColor)
      Text("/month")
        .font(Font(Fonts.titleRegular))
        .foregroundColor(foregroundColor.opacity(0.7))
    }
    .padding([.bottom])
    .background(backgroundColor)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
    .frame(maxWidth: 88)

  }
}

#Preview {
  ZStack {
    StoryBackgroundView()
    PricingBoxView(
      title: .constant("$1.99"),
      isSelected: .constant(true)
    )
  }
}
