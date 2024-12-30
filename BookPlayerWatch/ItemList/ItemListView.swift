//
//  ItemListView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 18/2/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct ItemListView: View {
  @EnvironmentObject var contextManager: ContextManager
  @State var showPlayer = false

  var body: some View {
    if contextManager.items.isEmpty {
      VStack {
        Spacer()
        Button {
          contextManager.requestData()
        } label: {
          Text("watchapp_refresh_data_title")
        }
        Spacer()
      }
    } else {
      List {
        ForEach(contextManager.items) { item in
          Button {
            contextManager.handleItemSelected(item)
            showPlayer = true
          } label: {
            ItemCellView(item: item)
          }
        }
      }
      .background(
        NavigationLink(
          destination: NowPlayingView()
            .environmentObject(contextManager),
          isActive: $showPlayer
        ) {
          EmptyView()
        }.opacity(0)
      )
      .onReceive(
        NotificationCenter.default.publisher(
          for: .bookPlaying
        )
      ) { _ in
        showPlayer = true
        contextManager.isPlaying = true
      }
      .onReceive(NotificationCenter.default.publisher(
        for: .bookPaused
      )) { _ in
        contextManager.isPlaying = false
      }
    }
  }
}
