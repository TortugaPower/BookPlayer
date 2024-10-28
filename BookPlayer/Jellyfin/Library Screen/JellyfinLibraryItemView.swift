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

  @ScaledMetric var accessabilityScale: CGFloat = 1
  @State private var imageSize: CGSize = CGSize.zero

  var body: some View {
    switch item.kind {
    case .audiobook:
      itemView
    case .userView, .folder:
      let childViewModel = viewModel.createFolderViewModelFor(item: item) as! Model
      NavigationLink {
        NavigationLazyView(JellyfinLibraryFolderView(viewModel: childViewModel))
      } label: {
        itemView
      }
      .buttonStyle(PlainButtonStyle())
    }
  }

  @ViewBuilder
  private var itemView: some View {
    VStack {
      ZStack(alignment: .topTrailing) {
        JellyfinLibraryItemImageView<Model>(item: item)
          .background(GeometryReader{ imageGeometry in
            Color.clear.onAppear {
              // we'd prever overlay to place the badge, but that's not available for us yet
              imageSize = imageGeometry.size
            }
          })

        switch item.kind {
        case .userView, .folder:
          folderBadge
        case .audiobook:
          EmptyView()
        }
      }

      Text(item.name)
        .lineLimit(1)
    }
  }

  @ViewBuilder
  private var folderBadge: some View {
    let imageLength = min(imageSize.width, imageSize.height)
    ZStack {
      Circle().strokeBorder(.foreground, lineWidth: 1 * accessabilityScale)
        .background(Circle().fill(.background))
      Image(systemName: "folder.fill")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: imageLength * 0.1, height: imageLength * 0.1)
    }
    .frame(width: imageLength * 0.2, height: imageLength * 0.2, alignment: .topTrailing)
    .padding(5)
    .opacity(0.8)
  }
}

#Preview("audiobook") {
  JellyfinLibraryItemView<MockJellyfinLibraryFolderViewModel>(item: JellyfinLibraryItem(id: "0.0", name: "An audiobook with a very very long name", kind: .audiobook))
    .environmentObject(MockJellyfinLibraryFolderViewModel(data: JellyfinLibraryItem(id: "0", name: "Parent", kind: .folder)))
}

#Preview("folder") {
  JellyfinLibraryItemView<MockJellyfinLibraryFolderViewModel>(item: JellyfinLibraryItem(id: "0.0", name: "Some folder", kind: .folder))
    .environmentObject(MockJellyfinLibraryFolderViewModel(data: JellyfinLibraryItem(id: "0", name: "Parent", kind: .folder)))
}
