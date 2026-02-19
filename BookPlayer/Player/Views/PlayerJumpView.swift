//
//  PlayerJumpView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct PlayerJumpView: View {
  let backgroundImage: Image
  let text: String
  let tintColor: Color
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      ZStack {
        backgroundImage
          .renderingMode(.template)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .foregroundColor(tintColor)
          .accessibilityHidden(true)
          .frame(width: 56, height: 56)
        
        Text(text)
          .bpFont(.title)
          .foregroundColor(tintColor)
          .multilineTextAlignment(.center)
          .lineLimit(1)
          .accessibilityHidden(true)
          .padding(.top, 4)
      }
    }
    .buttonStyle(.plain)
    .background(Color.clear)
    .frame(width: 54, height: 48)
  }
}

#Preview {
  PlayerJumpView(backgroundImage: Image(systemName: "gobackward"), text: "-20", tintColor: Color.green) {
    print("pressed")
  }
}
