//
//  EmptyListView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct EmptyListView: View {
  let node: LibraryNode
  let action: () -> Void

  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    VStack {
      if node == .root {
        Image(.emptyLibrary)
          .padding(.bottom, Spacing.L)
          .accessibilityHidden(true)
      } else {
        Image(.emptyPlaylist)
          .padding(.bottom, Spacing.L)
          .foregroundStyle(theme.linkColor)
          .accessibilityHidden(true)
      }

      Button(action: action) {
        Label {
          Text("playlist_add_title")
            .foregroundStyle(theme.linkColor)
        } icon: {
          Image(.listAdd)
            .foregroundStyle(theme.linkColor)
        }
      }
      .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#Preview {
  EmptyListView(node: .root) {}
    .environmentObject(ThemeViewModel())
}
