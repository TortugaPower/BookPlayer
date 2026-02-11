//
//  ArtworkView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct ArtworkView: View {
  var title: String = "Song Title"
  var author: String = "Artist Name"
  
  var body: some View {
    ZStack(alignment: .topTrailing) {
      
      RoundedRectangle(cornerRadius: 9.5)
        .fill(LinearGradient(
          gradient: Gradient(colors: [.gray.opacity(0.3), .black.opacity(0.7)]),
          startPoint: .top,
          endPoint: .bottom
        ))
      
      Image("artwork_placeholder") // Replace with your image logic
        .resizable()
        .aspectRatio(contentMode: .fit)
        .cornerRadius(9.5)
      
      Image("overlay_texture")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .cornerRadius(9.5)
      
      VStack {
        Spacer()
        Text(title)
          .accessibilityHidden(true)
        Text(author)
          .accessibilityHidden(true)
        
        AirplayPicker()
          .frame(width: 44, height: 44) // Standard touch target size
          .padding(.trailing, 5)
          .shadow(color: .black.opacity(1.0), radius: 3, x: 0, y: 2)
          .accessibilityElement(children: .combine)
          .accessibilityLabel(Text("audio_source_title"))
      }
      .padding()
      
      Image(systemName: "photo")
        .resizable()
        .scaledToFill()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cornerRadius(8)
        .foregroundColor(.gray.opacity(0.3))
      
      HStack(spacing: 12) {
        Spacer()
        BubbleButton(iconName: "sensor.tag.radiowaves.forward")
          .padding(.top, 8)
          .padding(.leading, 8)
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
