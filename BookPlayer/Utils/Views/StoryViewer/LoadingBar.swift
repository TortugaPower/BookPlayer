//
//  LoadingBar.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/6/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

struct LoadingBar: View {
  var progress: CGFloat

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Rectangle()
          .foregroundColor(Color.gray.opacity(0.9))
          .cornerRadius(5)

        Rectangle()
          .frame(width: geometry.size.width * progress, height: nil, alignment: .leading)
          .foregroundColor(Color.white.opacity(0.9))
          .cornerRadius(5)
      }
    }
  }
}

#Preview {
  VStack {
    LoadingBar(progress: 0.7)
      .frame(height: 2)
      .padding()
  }.background(Color.black)
}
