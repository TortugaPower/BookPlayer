//
//  RemoteItemListCellView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 18/11/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct RemoteItemListCellView: View {
  let item: SimpleLibraryItem

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(item.title)
          .lineLimit(2)
        Text(item.details)
          .font(.footnote)
          .foregroundColor(Color.secondary)
          .lineLimit(1)
      }
      Spacer()
      if item.type == .folder {
        Image(systemName: "chevron.forward")
      }
    }
  }
}
