//
//  FolderView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct FolderView: View {
  let item: SimpleLibraryItem
  let artworkTap: () -> Void

  var body: some View {
    NavigationLink(
      value: LibraryNode.folder(title: item.title, relativePath: item.relativePath)
    ) {
      BookView(item: item, artworkTap: artworkTap)
    }
  }
}
