//
//  ItemListView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 18/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import SwiftUI

struct ItemListView: View {
  var viewModel: ItemListModel

  var body: some View {
    if #available(watchOSApplicationExtension 8.0, *) {
      List {
        ForEach(viewModel.items) { item in
          NavigationLink(destination: NowPlayingView(item: item)) {
            ItemCellView(item: item)
          }
        }
      }
      .navigationTitle("recent_title")
      .navigationBarTitleDisplayMode(.inline)
    } else {
      List {
        ForEach(viewModel.items) { item in
          ItemCellView(item: item)
        }
      }
      .navigationTitle("recent_title")
    }
  }
}

struct ItemListView_Previews: PreviewProvider {
  static var previews: some View {
    ItemListView(viewModel: ItemListModel())
  }
}
