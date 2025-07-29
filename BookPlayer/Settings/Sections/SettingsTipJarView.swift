//
//  SettingsTipJarView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 24/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Kingfisher
import RevenueCat
import SwiftUI

struct SettingsTipJarView: View {
  @State private var showConfetti: Bool = false
  @State private var showSuccessAlert: Bool = false
  @State private var showRestoredAlert = false
  @State var loadingOverlay = LoadingOverlayState()
  @Environment(\.accountService) var accountService
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var theme: ThemeViewModel

  var alertTitle: LocalizedStringKey {
    accountService.hasPlusAccess()
      ? "thanks_amazing_title"
      : "thanks_title"
  }

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .center, spacing: 0) {
          Text("extra_tips_description")
            .multilineTextAlignment(.center)
            .padding(.vertical, Spacing.S)
          Text("support_bookplayer_title")
          SettingsTipOptionsView {
            showConfetti = true
            showSuccessAlert = true
            BPSKANManager.updateConversionValue(.donation)
            accountService.updateAccount(
              id: nil,
              email: nil,
              donationMade: true,
              hasSubscription: nil
            )
          }
          .padding(.top, Spacing.M)
          HStack(spacing: 35) {
            Spacer()
            ContributorView(
              contributor: .gianni,
              title: "@GianniCarlo",
              length: 70
            )
            ContributorView(
              contributor: .pichfl,
              title: "@pichfl",
              length: 70
            )
            Spacer()
          }
          .foregroundStyle(theme.secondaryColor)
          .padding(.top, Spacing.L1)
          .padding(.bottom, Spacing.S)
          ContributorsListView(availableWidth: geometry.size.width - (Spacing.L1 * 2))
            .padding(.horizontal, Spacing.L1)
        }
      }
      .scrollIndicators(.hidden)
    }
    .errorAlert(error: $loadingOverlay.error)
    .padding(.horizontal, Spacing.M)
    .background(theme.systemGroupedBackgroundColor)
    .environment(\.loadingOverlay, loadingOverlay)
    .navigationTitle("settings_tip_jar_title")
    .navigationBarTitleDisplayMode(.inline)
    .overlay {
      Group {
        ZStack {
          if showConfetti {
            ConfettiView()
          }
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
      }
      .ignoresSafeArea()
    }
    .alert(alertTitle, isPresented: $showSuccessAlert) {
      Button("ok_button", role: .cancel) {
        dismiss()
      }
    }
    .alert("purchases_restored_title", isPresented: $showRestoredAlert) {
      Button("ok_button", role: .cancel) {
        dismiss()
      }
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
              showConfetti = true
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

#Preview {
  @Previewable var accountService: AccountService = {
    let accountService = AccountService()
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: ""))
    accountService.setup(dataManager: dataManager)

    return accountService
  }()
  TabView {
    NavigationStack {
      SettingsTipJarView()
    }
    .tabItem {
      Image(systemName: "gearshape.fill")
      Text("Settings")
    }
  }
  .environmentObject(ThemeViewModel())
  .environment(\.accountService, accountService)
}
