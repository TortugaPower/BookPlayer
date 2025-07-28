//
//  SettingsAppIconsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import RevenueCat
import SwiftUI

struct SettingsAppIconsView: View {
  @State private var icons: [Icon] = Bundle.main.decodeIcons()
  @State var loadingOverlay = LoadingOverlayState()
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
    }
    .environment(\.loadingOverlay, loadingOverlay)
    .errorAlert(error: $loadingOverlay.error)
    .scrollContentBackground(.hidden)
    .background(theme.systemBackgroundColor)
    .listRowBackground(theme.secondarySystemBackgroundColor)
    .navigationTitle("settings_app_icon_title")
    .navigationBarTitleDisplayMode(.inline)
    .alert("purchases_restored_title", isPresented: $showRestoredAlert) {
      Button("ok_button", role: .cancel) {}
    }
    .overlay {
      Group {
        if loadingOverlay.show {
          ProgressView()
            .tint(.white)
            .padding()
            .background(
              Color.black
                .opacity(0.9)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            )
        }
      }
      .ignoresSafeArea()
    }
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("restore_title".localized) {
          loadingOverlay.show = true
          Task {
            do {
              let customerInfo = try await Purchases.shared.restorePurchases()

              if customerInfo.nonSubscriptions.isEmpty {
                loadingOverlay.show = false
                throw "tip_missing_title".localized
              }

              loadingOverlay.show = false
              showRestoredAlert = true

              accountService.updateAccount(
                id: nil,
                email: nil,
                donationMade: true,
                hasSubscription: nil
              )
            } catch {
              loadingOverlay.show = false
              loadingOverlay.error = error
            }
          }
        }
        .foregroundStyle(theme.linkColor)
      }
    }
  }
}

fileprivate extension Bundle {
  func decodeIcons() -> [Icon] {
    guard
      let url = self.url(forResource: "Icons", withExtension: "json"),
      let data = try? Data(contentsOf: url, options: .mappedIfSafe)
    else {
      return []
    }

    let icons = try? JSONDecoder().decode([Icon].self, from: data)

    return icons ?? []
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
