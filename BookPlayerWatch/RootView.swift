//
//  RootView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 22/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct RootView: View {
  @ObservedObject var coreServices: CoreServices
  @ObservedObject var contextManager = ExtensionDelegate.contextManager
  @State var showSettings = false

  var body: some View {
    VStack {
      if coreServices.hasSyncEnabled {
        RemoteItemListView(coreServices: coreServices)
      } else if contextManager.items.isEmpty && contextManager.isConnecting {
        ProgressView()
      } else {
        itemList
      }
    }
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button {
          showSettings = true
        } label: {
          Image(systemName: "gear")
        }
      }
    }
    .fullScreenCover(isPresented: $showSettings) {
      let account = coreServices.accountService.getAccount()
      SettingsView(
        account:
          account?.hasId == true
          ? account
          : nil
      )
      .environment(\.coreServices, coreServices)
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
