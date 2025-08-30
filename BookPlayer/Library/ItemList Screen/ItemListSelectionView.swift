//
//  ItemListSelectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ItemListSelectionView: View {
  let items: [SimpleLibraryItem]
  let onSelect: (SimpleLibraryItem) -> Void

  @State private var query = ""

  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.dismiss) private var dismiss

  var filteredResults: [SimpleLibraryItem] {
    var filteredItems = items

    if !query.isEmpty {
      filteredItems = filteredItems.filter {
        $0.title.localizedCaseInsensitiveContains(query) || $0.details.localizedCaseInsensitiveContains(query)
      }
    }
    return filteredItems
  }

  var body: some View {
    NavigationStack {
      List {
        ForEach(filteredResults, id: \.id) { item in
          BookView(item: item)
            .onTapGesture {
              onSelect(item)
              dismiss()
            }
            .listRowBackground(theme.systemBackgroundColor)
        }
      }
      .searchable(
        text: $query,
        prompt: "search_title"
      )
      .navigationTitle("select_item_title")
      .navigationBarTitleDisplayMode(.inline)
      .listStyle(.plain)
      .applyListStyle(with: theme, background: theme.systemBackgroundColor)
    }
  }
}

#Preview {
  ItemListSelectionView(items: []) { _ in }
}
