//
//  SkipIntervalView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 13/3/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct SkipIntervalView: View {
  let interval: Int?
  let skipDirection: SkipDirection

  private var isChapterSkip: Bool {
    guard let interval else { return false }
    return interval == Int(Constants.SkipInterval.chapterSkipValue)
  }

  var body: some View {
    ZStack {
      if isChapterSkip {
        Image(
          systemName: skipDirection == .forward
            ? "forward.end.fill"
            : "backward.end.fill"
        )
        .resizable()
        .aspectRatio(contentMode: .fit)
        .padding(12)
      } else {
        if let interval = interval {
          Text("**\(interval)**")
            .minimumScaleFactor(0.1)
            .lineLimit(1)
            .padding(5)
            .offset(y: 1)
        }

        ResizeableImageView(name: skipDirection.systemImage)
      }
    }
  }
}

struct SkipIntervalView_Previews: PreviewProvider {
  static var previews: some View {
    SkipIntervalView(interval: nil, skipDirection: .forward)
  }
}
