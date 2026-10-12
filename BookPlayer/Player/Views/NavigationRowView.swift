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
  /// Keeps the row as tall for a one-line title as for two. Off beside the artwork, where the
  /// row lines up with the artwork's top and the extra height would sit as empty space above
  /// a one-line title
  var keepsTitleHeight = true

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
          .frame(height: keepsTitleHeight ? 56 : nil)
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
