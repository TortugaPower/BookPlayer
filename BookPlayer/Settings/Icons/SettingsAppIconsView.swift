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
  @State var loadingState = LoadingOverlayState()
  @State private var showRestoredAlert = false
  @EnvironmentObject var theme: ThemeViewModel
  @Environment(\.accountService) private var accountService

  var showPro: () -> Void

  var body: some View {
    List {
      if accountService.accessLevel == .free {
        SettingsProBannerSectionView(showPro: showPro)
      }
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
    .alert("purchases_restored_title", isPresented: $showRestoredAlert) {
      Button("ok_button", role: .cancel) {}
    }
    .loadingOverlay(loadingState.show)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("restore_title".localized) {
          PurchasesManager.restoreTips(
            loadingState: loadingState
          ) {
            accountService.updateAccount(donationMade: true)
            showRestoredAlert = true
          }
        }
        .foregroundStyle(theme.linkColor)
      }
    }
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

    if  #available(iOS 26.0, *) {
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
    } else {
      icons = decodedIcons
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
    SettingsAppIconsView {}
  }
  .environmentObject(ThemeViewModel())
  .environment(\.accountService, accountService)
}
