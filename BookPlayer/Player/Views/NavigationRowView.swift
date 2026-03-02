//
//  NavigationRowView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct NavigationRowView: View {
  @EnvironmentObject private var theme: ThemeViewModel
  
  var playerTitle: String
  var hasNextChapter: Bool = false
  var hasPreviousChapter: Bool = false
  var onNextTap: (() -> Void)?
  var onTitleToggle: (() -> Void)?
  var onPreviousTap: (() -> Void)?
  
  var body: some View {
    HStack(spacing: 4) {
      Button {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onPreviousTap?()
      } label: {
        Image(systemName: hasPreviousChapter ? "chevron.left" : "chevron.left.2")
          .bpFont(.playerTitle)
          .tint(theme.primaryColor)
          .frame(height: 48)
          .frame(maxWidth: 48, alignment: .leading)
      }
      .accessibilityLabel("chapters_previous_title".localized)
      
      Spacer()
      
      Button {
        onTitleToggle?()
      } label: {
        Text(playerTitle)
          .bpFont(.playerTitle)
          .foregroundColor(theme.primaryColor)
          .multilineTextAlignment(.center)
          .frame(height: 56)
      }
      .layoutPriority(1)
      
      Spacer()
      
      Button {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onNextTap?()
      } label: {
        Image(systemName: hasNextChapter ? "chevron.right" : "chevron.right.2")
          .bpFont(.playerTitle)
          .tint(theme.primaryColor)
          .frame(height: 48)
          .frame(maxWidth: 48, alignment: .trailing)
      }
      .accessibilityLabel("chapters_next_title".localized)
    }
    .environment(\.layoutDirection, .leftToRight)
  }
}

#Preview {
  NavigationRowView(playerTitle: "Chapter 1")
}
