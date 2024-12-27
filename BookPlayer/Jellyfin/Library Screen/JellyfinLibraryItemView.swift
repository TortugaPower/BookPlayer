//
//  JellyfinLibraryItemView.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-28.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import Kingfisher

struct JellyfinLibraryItemView<LibraryVM: JellyfinLibraryViewModelProtocol>: View {
  @State var item: JellyfinLibraryItem
  @EnvironmentObject var libraryVM: LibraryVM
  
  @ScaledMetric var accessabilityScale: CGFloat = 1
  @State private var imageSize: CGSize = CGSize.zero
  
  var body: some View {
    switch item.kind {
    case .audiobook:
      NavigationLink {
        NavigationLazyView(libraryVM.createAudiobookDetailsViewFor(item: item))
        .environmentObject(libraryVM)
      } label: {
        itemView
      }
      .buttonStyle(PlainButtonStyle())
    case .userView, .folder:
      NavigationLink {
        NavigationLazyView(libraryVM.createFolderViewFor(item: item))
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
        JellyfinLibraryItemImageView<LibraryVM>(item: item)
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
        .truncationMode(.middle)
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
  let parentData = JellyfinLibraryLevelData.topLevel(libraryName: "Mock Library", userID: "42")
  JellyfinLibraryItemView<MockJellyfinLibraryViewModel>(item: JellyfinLibraryItem(id: "0.0", name: "An audiobook with a very very long name", kind: .audiobook))
    .environmentObject(MockJellyfinLibraryViewModel(data: parentData))
}

#Preview("folder") {
  let parentData = JellyfinLibraryLevelData.topLevel(libraryName: "Mock Library", userID: "42")
  JellyfinLibraryItemView<MockJellyfinLibraryViewModel>(item: JellyfinLibraryItem(id: "0.0", name: "Some folder", kind: .folder))
    .environmentObject(MockJellyfinLibraryViewModel(data: parentData))
}
