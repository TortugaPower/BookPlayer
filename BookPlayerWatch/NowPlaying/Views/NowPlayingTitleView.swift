//
//  NowPlayingTitleView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 19/2/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct NowPlayingTitleView: View {
  @Binding var item: PlayableItem?

  var body: some View {
    VStack(alignment: .leading) {
      Spacer()
        .frame(maxWidth: .infinity, maxHeight: 0)
      Text(item?.author ?? "")
        .font(.subheadline.smallCaps())
        .foregroundColor(Color.secondary)
        .lineLimit(1)
      Text(item?.title ?? "")
        .font(.headline)
        .foregroundColor(Color.primary)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
