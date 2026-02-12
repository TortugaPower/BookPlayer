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
  var title: String = "Song Title"
  var author: String = "Unknown Author"
  var imagePath: String?
  
  var body: some View {
    ZStack(alignment: .topTrailing) {
      
      RoundedRectangle(cornerRadius: 9.5)
        .fill(LinearGradient(
          gradient: Gradient(colors: [.gray.opacity(0.3), .black.opacity(0.7)]),
          startPoint: .top,
          endPoint: .bottom
        ))
      
      if imagePath != nil {
        KFImage
          .dataProvider(ArtworkService.getArtworkProvider(for: imagePath!))
          .placeholder {
            theme.defaultArtwork
          }
          .targetCache(ArtworkService.cache)
          .resizable()
          .placeholder {
            // Equivalent to your placeholder logic
            Color.gray.opacity(0.3)
          }
          .onSuccess { _ in
            imageLoaded = true
          }
          .scaledToFill()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .aspectRatio(contentMode: .fit)
          .cornerRadius(8)
      } else {
        Image(systemName: "photo")
          .resizable()
          .scaledToFill()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .aspectRatio(contentMode: .fit)
          .cornerRadius(8)
          .foregroundColor(.gray.opacity(0.3))
      }
      
      if !imageLoaded {
        VStack(alignment: .leading) {
          Text(author)
            .accessibilityHidden(true)
          Text(imagePath ?? title)
            .padding(.vertical, 4)
            .accessibilityHidden(true)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
      }
      
      HStack(spacing: 12) {
        Spacer()
        Button {
          
        } label: {
          AirplayPicker()
            .frame(width: 44, height: 44) // Standard touch target size
            .padding(.trailing, 5)
            .shadow(color: .black.opacity(1.0), radius: 3, x: 0, y: 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("audio_source_title"))
        }
      }
      .frame(maxWidth: .infinity)
    }
    .frame(maxWidth: .infinity)
    .aspectRatio(1, contentMode: .fit)
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
    ArtworkView()
}
