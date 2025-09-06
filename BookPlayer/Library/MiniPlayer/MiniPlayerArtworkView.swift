//
//  MiniPlayerArtworkView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Kingfisher
import SwiftUI

struct MiniPlayerArtworkView: View {
  let relativePath: String?
  @State private var artworkReloadBump = false
  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    ZStack {
      Color.black
      if let relativePath {
        KFImage
          .dataProvider(ArtworkService.getArtworkProvider(for: relativePath))
          .placeholder { theme.defaultArtwork }
          .targetCache(ArtworkService.cache)
          .resizable()
          .aspectRatio(contentMode: .fit)
      } else {
        theme.defaultArtwork
      }
    }
    .frame(width: 50, height: 50)
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .mask(RoundedRectangle(cornerRadius: 4))
    .id(artworkReloadBump)
    .onReceive(
      ArtworkService.artworkUpdatePublisher
        .filter { $0 == relativePath }
    ) { _ in
      artworkReloadBump.toggle()
    }
  }
}

#Preview {
  MiniPlayerArtworkView(relativePath: "path/to/file.mp3")
}
