//
//  BookPlayerApp.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 18/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import SwiftUI

@main
struct BookPlayerApp: App {
  @WKExtensionDelegateAdaptor var extensionDelegate: ExtensionDelegate

  @SceneBuilder var body: some Scene {
    WindowGroup {
      NavigationView {
        ContainerItemListView()
      }
    }
  }
}
