//
//  JellyfinLibraryListItemView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/6/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct JellyfinLibraryListItemView: View {
  @State var item: JellyfinLibraryItem
  @EnvironmentObject var themeViewModel: ThemeViewModel

  var body: some View {
    HStack {
      JellyfinLibraryItemImageView(item: item)
        .frame(width: 50, height: 50)
        .accessibilityHidden(true)
      Text(item.name)
        .font(Font(Fonts.titleRegular))
        .foregroundStyle(themeViewModel.primaryColor)
      Spacer()
      if item.kind != .audiobook {
        Image(systemName: "chevron.forward")
          .foregroundStyle(themeViewModel.secondaryColor)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

#Preview("book") {
  JellyfinLibraryListItemView(item: JellyfinLibraryItem(id: "0.1", name: "book", kind: .audiobook))
}

#Preview("folder") {
  JellyfinLibraryListItemView(item: JellyfinLibraryItem(id: "0.0", name: "subfolder", kind: .folder))
}
