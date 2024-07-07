//
//  StoryProgress.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/6/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

struct StoryProgress: View {
  @Binding var storiesCount: Int
  @Binding var progress: Double

  var body: some View {
    HStack(alignment: .center, spacing: 4) {
      ForEach(0..<storiesCount, id: \.self) { image in
        LoadingBar(progress: min( max( (CGFloat(progress) - CGFloat(image)), 0.0), 1.0) )
          .frame(width: nil, height: 2, alignment: .leading)
          .animation(.linear)
      }
    }
  }
}

#Preview {
  VStack {
    StoryProgress(
      storiesCount: .constant(3),
      progress: .constant(1)
    )
      .frame(height: 2)
      .padding()
      .animation(.linear)
  }.background(Color.black)

}
