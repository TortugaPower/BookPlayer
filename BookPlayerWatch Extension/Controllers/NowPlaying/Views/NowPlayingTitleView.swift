//
//  NowPlayingTitleView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 19/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import SwiftUI

struct NowPlayingTitleView: View {
  let author: String
  let title: String
  var body: some View {
    VStack(alignment: .leading) {
      Spacer()
        .frame(maxWidth: .infinity, maxHeight: 0)
      Text(author)
        .font(.subheadline.smallCaps())
        .foregroundColor(Color.secondary)
        .lineLimit(1)
      Text(title)
        .font(.headline)
        .foregroundColor(Color.primary)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

struct NowPlayingTitleView_Previews: PreviewProvider {
  static var previews: some View {
    NowPlayingTitleView(author: "author 1", title: "title 1 title 1 title 1 title 1 title 1")
  }
}
