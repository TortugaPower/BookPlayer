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
      ZStack {
        // 1. Create the square "box"
        Color.clear
          .aspectRatio(1, contentMode: .fit)
        
        Rectangle()
          .fill(Color.secondary.opacity(0.1)) // A base color for while things load
          .aspectRatio(1, contentMode: .fit)   // This locks it into a square
          .overlay(
            KFImage
              .dataProvider(ArtworkService.getArtworkProvider(for: imagePath ?? ""))
              .targetCache(ArtworkService.cache)
              .downsampling(size: CGSize(width: 100, height: 100))
              .resizable()
              .scaledToFill() // Fill the entire square
              .blur(radius: 20) // Adjust for more/less blur
              .opacity(0.6)    // Soften it so it doesn't distract
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .accessibilityHidden(true)
          )
          .accessibilityHidden(true)
        
        // 2. Place the image inside
        KFImage
          .dataProvider(ArtworkService.getArtworkProvider(for: imagePath ?? ""))
          .placeholder {
            Rectangle()
              .overlay(
                ZStack {
                  theme.defaultArtwork?
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                  
                  VStack(alignment: .leading) {
                    Spacer()
                    
                    Text(author)
                      .lineLimit(1)
                      .bpFont(.title2)
                      .opacity(0.6)
                      .accessibilityHidden(true)
                    Text(title)
                      .lineLimit(2)
                      .bpFont(.title2)
                      .padding(.vertical, 4)
                      .accessibilityHidden(true)
                  }
                  .padding()
                  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                  .accessibilityHidden(true)
                }
              )
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
          .targetCache(ArtworkService.cache)
          .resizable()
          .scaledToFit()
          .accessibilityLabel(VoiceOverService.playerMetaText(title: title, author: author))
          .accessibilityAddTraits(.isStaticText)
          .accessibilityRemoveTraits(.isImage)
        
        VStack {
          HStack(spacing: 12) {
            Spacer()
            AirplayPicker()
              .frame(width: 44, height: 44) // Standard touch target size
              .padding(.trailing, 5)
              .padding(.top, 5)
              .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
              .accessibilityElement(children: .combine)
              .accessibilityLabel(Text("audio_source_title"))
          }
          .frame(maxWidth: .infinity)
          
          Spacer()
        }
      }
      .aspectRatio(1, contentMode: .fit)
      .cornerRadius(12)
      .clipped()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#Preview {
  ArtworkView(title: "Unknown Book", author: "Unknown Artist")
}
