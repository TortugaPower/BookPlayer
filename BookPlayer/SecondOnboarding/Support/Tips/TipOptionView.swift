//
//  TipOptionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/2/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct TipOptionView: View {
  @Binding var title: String
  @Binding var price: String
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

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Spacer()
        Image(systemName: imageName)
          .resizable()
          .frame(width: imageLength, height: imageLength)
          .foregroundStyle(foregroundColor)
          .padding([.trailing, .top], Spacing.S3)
      }
      Text(title)
        .font(Font(Fonts.titleRegular))
        .foregroundStyle(foregroundColor.opacity(0.7))
        .multilineTextAlignment(.center)
      Text(price)
        .font(Font(Fonts.titleLarge))
        .foregroundStyle(foregroundColor)
    }
    .padding([.bottom])
    .background(Color(UIColor(hex: "F8F8F8")))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
    .frame(maxWidth: 88)

  }
}

#Preview {
  ZStack {
    TipOptionView(
      title: .constant("Kind tip\nof"),
      price: .constant("1.99"),
      isSelected: .constant(true)
    )
  }
}
