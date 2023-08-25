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
  @ObservedObject var contextManager = ExtensionDelegate.contextManager
  @State var showPlayer = false
  
  var body: some View {
    VStack {
      if contextManager.items.isEmpty,
         contextManager.isConnecting {
        ProgressView()
      } else if #available(watchOSApplicationExtension 8.0, *) {
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
