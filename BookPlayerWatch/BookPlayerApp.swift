//
//  BookPlayerApp.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 18/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import RevenueCat
import SwiftUI

@main
struct BookPlayerApp: App {
  // swiftlint:disable:next weak_delegate
  @WKApplicationDelegateAdaptor var extensionDelegate: ExtensionDelegate

  init() {
    let revenueCatApiKey: String = Bundle.main.configurationValue(
      for: .revenueCat
    )
    Purchases.logLevel = .error
    Purchases.configure(withAPIKey: revenueCatApiKey)
  }

  @SceneBuilder var body: some Scene {
    WindowGroup {
      NavigationView {
        ContainerItemListView()
      }
    }
  }
}
