//
//  ContainerItemListView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 22/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct ContainerItemListView: View {
  @ObservedObject var contextManager = ExtensionDelegate.contextManager
  @State var showPlayer = false
  @State var showSettings = false

  var body: some View {
    VStack {
      if contextManager.items.isEmpty,
        contextManager.isConnecting
      {
        ProgressView()
      } else {
        itemList
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button {
                print("Settings")
                showSettings = true
              } label: {
                Image(systemName: "gear")
              }
            }
          }
          .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
          }
      }
    }
  }

  var itemList: some View {
    Group {
      if #available(watchOS 8.0, *) {
        ItemListView()
          .navigationTitle("recent_title")
          .navigationBarTitleDisplayMode(.inline)
          .environmentObject(contextManager)
      } else {
        ItemListView()
          .navigationTitle("recent_title")
          .environmentObject(contextManager)
      }
    }
  }
}

struct ContainerItemListView_Previews: PreviewProvider {
  static var previews: some View {
    ContainerItemListView()
  }
}
