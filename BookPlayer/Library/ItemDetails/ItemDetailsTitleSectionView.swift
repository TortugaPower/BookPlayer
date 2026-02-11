//
//  ItemDetailsTitleSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 6/9/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ItemDetailsTitleSectionView: View {
  @Binding var title: String
  let titlePlaceholder: String
  let showAuthor: Bool
  @Binding var author: String
  let authorPlaceholder: String

  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    ThemedSection {
      ClearableTextField(titlePlaceholder, text: $title)
      if showAuthor {
        ClearableTextField(authorPlaceholder, text: $author)
      }
    } header: {
      Text("details_title")
        .foregroundStyle(theme.secondaryColor)
    }
    .listRowBackground(theme.secondarySystemBackgroundColor)
  }
}

#Preview {
  @Previewable var title = ""
  @Previewable var author = ""

  ItemDetailsTitleSectionView(
    title: .constant(title),
    titlePlaceholder: "title",
    showAuthor: true,
    author: .constant(author),
    authorPlaceholder: "author"
  )
}
