//
//  ItemCellView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 19/2/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import BookPlayerWatchKit

struct ItemCellView: View {
  let item: PlayableItem

  var body: some View {
    VStack(alignment: .leading) {
      Text(item.title)
        .foregroundColor(Color.primary)
        .lineLimit(2)
      Text(item.author)
        .font(.footnote)
        .foregroundColor(Color.secondary)
        .lineLimit(1)
    }
  }
}

struct ItemCellView_Previews: PreviewProvider {
  static var previews: some View {
    List {
      ItemCellView(item: PlayableItem(
        title: "book 1",
        author: "author 1",
        chapters: [],
        currentTime: 0,
        duration: 0,
        relativePath: "book 1",
        parentFolder: nil,
        percentCompleted: 0,
        lastPlayDate: nil,
        isFinished: false,
        isBoundBook: false
      ))
    }
  }
}
