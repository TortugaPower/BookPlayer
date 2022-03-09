//
//  ContainerItemListView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 22/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import SwiftUI
import BookPlayerWatchKit

struct ContainerItemListView: View {
  @StateObject var viewModel = ItemListModel()

  var body: some View {
    VStack {
      if #available(watchOSApplicationExtension 8.0, *) {
        ItemListView()
          .navigationTitle("recent_title")
          .navigationBarTitleDisplayMode(.inline)
          .environmentObject(viewModel)
      } else {
        ItemListView()
          .navigationTitle("recent_title")
          .environmentObject(viewModel)
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .bookPlaying)) { _ in
      print("==")
    }
  }
}

struct ContainerItemListView_Previews: PreviewProvider {
  static var previews: some View {
    ContainerItemListView()
  }
}
