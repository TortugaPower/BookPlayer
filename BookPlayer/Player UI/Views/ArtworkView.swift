//
//  ArtworkView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct ArtworkView: View {
  var body: some View {
    ZStack(alignment: .topTrailing) {
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
