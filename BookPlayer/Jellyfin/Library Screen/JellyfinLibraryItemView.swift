//
//  JellyfinLibraryItemView.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-28.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI
import Kingfisher

struct JellyfinLibraryItemView<Model: JellyfinLibraryFolderViewModelProtocol>: View {
  @State var item: JellyfinLibraryItem
  @EnvironmentObject var viewModel: Model

  var body: some View {
    switch item.kind {
    case .audiobook:
      itemView
    case .userView, .folder:
      let childViewModel = viewModel.createFolderViewModelFor(item: item) as! Model
      NavigationLink(destination: NavigationLazyView(JellyfinLibraryFolderView(viewModel: childViewModel))) {
        itemView
      }
    }
  }

  @ViewBuilder
  private var itemView: some View {
    VStack {
      JellyfinLibraryItemImageView<Model>(item: item)
      Text(item.name)
        .lineLimit(1)
    }
  }
}

#Preview("audiobook") {
  JellyfinLibraryItemView<MockJellyfinLibraryFolderViewModel>(item: JellyfinLibraryItem(id: "0.0", name: "An audiobook with a very very long name", kind: .audiobook))
  .environmentObject(MockJellyfinLibraryFolderViewModel(data: JellyfinLibraryItem(id: "0", name: "Parent", kind: .folder)))
}
