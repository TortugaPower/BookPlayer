//
//  ItemDetailsFooterSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 6/9/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ItemDetailsFooterSectionView: View {
  let originalFileName: String
  let progress: Double
  let lastPlayedDate: String?

  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    ThemedSection {
      EmptyView()
    } footer: {
      VStack(alignment: .leading) {
        Text(originalFileName)
        Text(progress.formatted(.percent))
        + Text(" \("progress_title".localized)".lowercased())
        if let lastPlayedDate {
          Text("watchapp_last_played_title".localized)
            + Text(": " + lastPlayedDate)
        }
      }
      .bpFont(.body)
      .foregroundStyle(theme.secondaryColor)
    }
  }
}

#Preview {
  ItemDetailsFooterSectionView(
    originalFileName: "My_Book.m4b",
    progress: 12,
    lastPlayedDate: "6 sept 2025, 5:30 AM"
  )
}
