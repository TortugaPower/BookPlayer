//
//  JellyfinLibraryItemView.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-28.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI
import Kingfisher

struct JellyfinLibraryItemImageView<Model: JellyfinLibraryFolderViewModelProtocol>: View {
  @State var item: JellyfinLibraryItem
  @EnvironmentObject var viewModel: Model

  var body: some View {
    KFImage
      .url(viewModel.createItemImageURL(item))
      .cacheMemoryOnly()
      .resizable()
      .placeholder { ProgressView() }
      .frame(width: 100, height: 100)
      .cornerRadius(3)
  }
}

#Preview("audiobook") {
  JellyfinLibraryItemImageView<MockJellyfinLibraryFolderViewModel>(item: JellyfinLibraryItem(id: "0.0", name: "An audiobook", kind: .audiobook))
  .environmentObject(MockJellyfinLibraryFolderViewModel(data: JellyfinLibraryItem(id: "0", name: "Parent", kind: .folder)))
}
