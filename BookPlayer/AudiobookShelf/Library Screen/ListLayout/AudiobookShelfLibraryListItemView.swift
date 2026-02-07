//
//  AudiobookShelfLibraryListItemView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct AudiobookShelfLibraryListItemView: View {
  @State var item: AudiobookShelfLibraryItem
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    HStack {
      AudiobookShelfLibraryItemImageView(item: item)
        .frame(width: 50, height: 50)
        .accessibilityHidden(true)
      Text(item.title)
        .bpFont(.titleRegular)
        .foregroundStyle(theme.primaryColor)
      Spacer()
      if item.kind == .library {
        Image(systemName: "chevron.forward")
          .foregroundStyle(theme.secondaryColor)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

#Preview("book") {
  AudiobookShelfLibraryListItemView(
    item: AudiobookShelfLibraryItem(
      id: "0.1",
      title: "The Great Gatsby",
      kind: .audiobook,
      libraryId: "1"
    )
  )
  .environmentObject(ThemeViewModel())
}
