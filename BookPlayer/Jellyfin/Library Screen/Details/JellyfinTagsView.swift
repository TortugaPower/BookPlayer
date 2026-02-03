//
//  JellyfinTagsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 31/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct JellyfinTagsView: View {
  let tags: [String]

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    TagsFlowLayout {
      ForEach(tags, id: \.self) { tag in
        Text(tag)
          .bpFont(.caption)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .foregroundColor(theme.primaryColor)
          .overlay(
            Capsule()
              .stroke(theme.linkColor, lineWidth: 1)
          )
      }
    }
    .padding(Spacing.S4)
  }
}

#Preview {
  JellyfinTagsView(tags: ["Sci-Fi", "Fantasy", "Dystopian", "Action", "Adventure", "Mystery", "Horror", "Thriller"])
    .environmentObject(ThemeViewModel())
}
