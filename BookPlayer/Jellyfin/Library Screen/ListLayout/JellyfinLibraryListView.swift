//
//  JellyfinLibraryListView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/6/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct JellyfinLibraryListView<Model: JellyfinLibraryViewModelProtocol>: View {
  @ObservedObject var viewModel: Model
  
  var body: some View {
    List {
      ForEach(viewModel.items, id: \.id) { item in
        JellyfinLibraryListItemView(item: item)
          .contentShape(Rectangle())
          .onTapGesture {
            switch item.kind {
            case .audiobook:
              viewModel.navigation.path.append(
                JellyfinLibraryLevelData.details(data: item)
              )
            case .userView, .folder:
              viewModel.navigation.path.append(
                JellyfinLibraryLevelData.folder(data: item)
              )
            }
          }
          .onAppear {
            viewModel.fetchMoreItemsIfNeeded(currentItem: item)
          }
      }
    }
  }
}
