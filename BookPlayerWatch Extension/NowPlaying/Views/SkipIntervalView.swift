//
//  SkipIntervalView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 13/3/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import SwiftUI

struct SkipIntervalView: View {
  let interval: Int?
  let skipDirection: SkipDirection
  
  var body: some View {
    ZStack {
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

struct SkipIntervalView_Previews: PreviewProvider {
  static var previews: some View {
    SkipIntervalView(interval: nil, skipDirection: .forward)
  }
}
