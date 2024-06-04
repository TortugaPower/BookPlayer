//
//  StoryBackgroundView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/6/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

struct StoryBackgroundView: View {
  var body: some View {
    Rectangle()
      .fill(LinearGradient(
        gradient: Gradient(colors: [
          Color(UIColor(hex: "4285C5")),
          Color(UIColor(hex: "3D4494"))
        ]),
        startPoint: .bottomLeading,
        endPoint: .topTrailing
      ))
      .ignoresSafeArea()
  }
}

#Preview {
  StoryBackgroundView()
}
