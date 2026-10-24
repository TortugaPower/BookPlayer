//
//  SettingsAppIconsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct SettingsAppIconsView: View {
  @State private var icons: [Icon] = Bundle.main.decodeIcons()
  /// For the errors of changing the icon (AppIconView)
  @State var loadingState = LoadingOverlayState()
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    List {
      ForEach(icons) { item in
        AppIconView(icon: item)
      }
      .listRowBackground(theme.tertiarySystemBackgroundColor)
    }
    .environment(\.loadingState, loadingState)
    .errorAlert(error: $loadingState.error)
    .scrollContentBackground(.hidden)
    .background(theme.systemBackgroundColor)
    .navigationTitle("settings_app_icon_title")
    .navigationBarTitleDisplayMode(.inline)
    .loadingOverlay(loadingState.show)
    .unlocksWithTipJar()
  }
}

extension Bundle {
  fileprivate func decodeIcons() -> [Icon] {
    guard
      let url = self.url(forResource: "Icons", withExtension: "json"),
      let data = try? Data(contentsOf: url, options: .mappedIfSafe)
    else {
      return []
    }

    let decodedIcons = (try? JSONDecoder().decode([Icon].self, from: data)) ?? []

    var icons = [Icon]()

    for var icon in decodedIcons {
      if icon.title == "Pride" {
        icon.id += "26"
        icon.imageName += "-26"
      } else if icon.title == "Fruit Based" {
        icon.id += "26"
        icon.title = "Books"
        icon.imageName += "-26"
      }
      icons.append(icon)
    }

    return icons
  }
}

#Preview {
  @Previewable var accountService: AccountService = {
    let accountService = AccountService()
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: ""))
    accountService.setup(dataManager: dataManager)
    accountService.accessLevel = .free

    return accountService
  }()

  NavigationStack {
    SettingsAppIconsView()
  }
  .environmentObject(ThemeViewModel())
  .environment(\.accountService, accountService)
}
