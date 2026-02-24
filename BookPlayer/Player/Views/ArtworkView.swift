//
//  ArtworkView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import Kingfisher
import BookPlayerKit

struct ArtworkView: View {
  @EnvironmentObject private var theme: ThemeViewModel
  @State var imageLoaded = false
  var title: String
  var author: String
  var imagePath: String?
  
  var body: some View {
    ZStack(alignment: .top) {
      
      if let myImagePath = imagePath {
        KFImage
          .dataProvider(ArtworkService.getArtworkProvider(for: myImagePath))
          .placeholder {
            theme.defaultArtwork?
              .resizable()
              .aspectRatio(contentMode: .fit)
              .cornerRadius(12)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
          .targetCache(ArtworkService.cache)
          .onSuccess { _ in
            imageLoaded = true
          }
          .resizable()
          .aspectRatio(contentMode: .fit)
          .cornerRadius(12)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .accessibilityLabel(VoiceOverService.playerMetaText(
            title: title,
            author: author
          ))
          .accessibilityAddTraits(.isStaticText)
          .accessibilityRemoveTraits(.isImage)
      } else {
        theme.defaultArtwork?
          .resizable()
          .aspectRatio(contentMode: .fit)
          .cornerRadius(12)
          .accessibilityHidden(true)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .accessibilityLabel(VoiceOverService.playerMetaText(
            title: title,
            author: author
          ))
          .accessibilityAddTraits(.isStaticText)
          .accessibilityRemoveTraits(.isImage)
      }
      
      if !imageLoaded {
        VStack(alignment: .leading) {
          Text(author)
            .bpFont(.title2)
            .opacity(0.6)
            .accessibilityHidden(true)
          Text(title)
            .bpFont(.title2)
            .padding(.vertical, 4)
            .accessibilityHidden(true)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .accessibilityHidden(true)
      }
      
      HStack(spacing: 12) {
        Spacer()
        AirplayPicker()
          .frame(width: 44, height: 44) // Standard touch target size
          .padding(.trailing, 5)
          .padding(.top, 5)
          .shadow(color: .black.opacity(1.0), radius: 3, x: 0, y: 2)
          .accessibilityElement(children: .combine)
          .accessibilityLabel(Text("audio_source_title"))
      }
      .frame(maxWidth: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    
  }
  
  func floatingIcon(_ name: String) -> some View {
    Image(systemName: name)
      .foregroundColor(.primary)
      .padding(8)
      .background(.ultraThinMaterial)
      .clipShape(Circle())
  }
}

#Preview {
  ArtworkView(title: "Unknown Book", author: "Unknown Artist")
}
