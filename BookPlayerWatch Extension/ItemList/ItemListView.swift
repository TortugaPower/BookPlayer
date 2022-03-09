//
//  ItemListView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 18/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import SwiftUI

struct ItemListView: View {
  @EnvironmentObject var viewModel: ItemListModel

  var body: some View {
    if viewModel.items.isEmpty {
      VStack {
        Spacer()
        Button {
          viewModel.requestData()
          print("reload tapped")
        } label: {
          Text("watchapp_refresh_data_title")
        }
        Spacer()
      }
    } else {
      List {
        ForEach(viewModel.items) { item in
          NavigationLink(destination: ContainerNowPlayingView(item: item)) {
            ItemCellView(item: item)
          }
        }
      }
    }
  }
}

struct ItemListView_Previews: PreviewProvider {
  static var previews: some View {
    ItemListView()
      .environmentObject(ItemListModel())
  }
}
