//
//  SettingsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import DeviceKit
import MessageUI
import RevenueCat
import SwiftUI

struct SettingsView: View {
  @State private var path = NavigationPath()
  @State var showMailModal = false
  @State var showMailUnavailableModal = false
  @State var showLogin = false
  @State var showCompleteAccount = false
  @State var loadingState = LoadingOverlayState()

  @Environment(\.listState) private var listState
  @Environment(\.libraryService) private var libraryService
  @Environment(\.syncService) private var syncService
  @Environment(\.accountService) private var accountService
  @Environment(\.jellyfinService) private var jellyfinService
  @Environment(\.hardcoverService) private var hardcoverService
  @Environment(\.playerState) private var playerState
  @EnvironmentObject private var theme: ThemeViewModel

  let supportEmail = "support@bookplayer.app"

  var body: some View {
    NavigationStack(path: $path) {
      Form {
        if accountService.accessLevel == .free {
          SettingsProBannerSectionView(showPro: showPro)
        }
        SettingsAppearanceSectionView()
        SettingsPlaybackSectionView()
        SettingsStorageSectionView(accessLevel: accountService.accessLevel)
        if accountService.accessLevel == .pro {
          SettingsDataUsageSectionView()
        }
        SettingsShortcutsSectionView()
        SettingsiCloudSectionView()
        SettingsIntegrationsSectionView()
        SettingsPrivacySectionView()
        SettingsSupportSectionView(accessLevel: accountService.accessLevel) {
          if MFMailComposeViewController.canSendMail() {
            showMailModal.toggle()
          } else {
            showMailUnavailableModal.toggle()
          }
        }
        SettingsCreditsSectionView()
      }
      .environment(\.loadingState, loadingState)
      .navigationTitle("settings_title")
      .navigationBarTitleDisplayMode(.inline)
      .applyListStyle(with: theme, background: theme.systemGroupedBackgroundColor)
      .miniPlayerSafeAreaInset()
      .sheet(isPresented: $showMailModal) {
        SettingsMailView(
          recipients: [supportEmail],
          subject: emailSubject,
          messageBody: emailBody,
          isHTML: true,
          attachmentData: attachmentData
        )
      }
      .errorAlert(error: $loadingState.error)
      .alert("settings_support_compose_title", isPresented: $showMailUnavailableModal) {
        Button("settings_support_compose_copy") {
          UIPasteboard.general.string = debugInfo
        }
        Button("ok_button", role: .cancel) {}
      } message: {
        Text(debugInfoDescription)
      }
      .navigationDestination(for: SettingsScreen.self) { destination in
        let view: AnyView
        switch destination {
        case .themes:
          view = AnyView(SettingsThemesView(showPro: showPro))
        case .icons:
          view = AnyView(SettingsAppIconsView(showPro: showPro))
        case .controls:
          view = AnyView(SettingsPlayerControlsView())
        case .autoplay:
          view = AnyView(SettingsAutoplayView())
        case .autolock:
          view = AnyView(SettingsAutolockView())
        case .storage:
          view = AnyView(
            StorageView(
              viewModel:
                StorageViewModel(
                  libraryService: libraryService,
                  syncService: syncService,
                  folderURL: DataManager.getProcessedFolderURL(),
                  listState: listState
                )
            )
          )
        case .syncbackup:
          view = AnyView(
            StorageCloudDeletedView(
              viewModel:
                StorageCloudDeletedViewModel(folderURL: DataManager.getBackupFolderURL())
            )
          )
        case .jellyfin:
          view = AnyView(
            JellyfinSettingsView(
              viewModel: JellyfinConnectionViewModel(
                connectionService: jellyfinService,
                navigation: BPNavigation(),
                mode: .viewDetails
              )
            )
          )
        case .hardcover:
          view = AnyView(
            HardcoverSettingsView(
              viewModel: HardcoverSettingsViewModel(hardcoverService: hardcoverService)
            )
          )
        case .tipjar:
          view = AnyView(SettingsTipJarView())
        case .credits:
          view = AnyView(CreditsView())
        default:
          view = AnyView(EmptyView())
        }

        return
          view
          .miniPlayerSafeAreaInset()
      }
      .sheet(isPresented: $showLogin) {
        NavigationStack {
          LoginView()
        }
      }
      .sheet(isPresented: $showCompleteAccount) {
        SettingsCompleteAccountView()
          .presentationDetents([.medium])
      }
    }
    .foregroundStyle(theme.primaryColor)
    .tint(theme.linkColor)
  }

  private func showPro() {
    if accountService.getAccountId() != nil {
      showCompleteAccount = true
    } else {
      showLogin = true
    }
  }

  // MARK: - Email utils
  private var emailSubject: String {
    "I need help with BookPlayer \(appVersion)\(versionSuffix)"
  }

  private var emailBody: String {
    "<p>Hello,<br>I have an issue when I try to…</p><br/>"
  }

  private var versionSuffix: String {
    switch accountService.accessLevel {
    case .free, .none:
      return ""
    case .plus:
      return "p"
    case .pro:
      return "c"
    }
  }

  private var attachmentData: AttachmentData? {
    guard let cachedCustomerInfo = Purchases.shared.cachedCustomerInfo else {
      return nil
    }

    let info =
      "\(cachedCustomerInfo.id)\nApp version: \(appVersion)\(versionSuffix)\n\(systemVersion)"

    guard let data = info.data(using: .utf8) else {
      return nil
    }

    return AttachmentData(
      data: data,
      mimeType: "text/plain",
      fileName: "build-info.txt"
    )
  }

  private var debugInfoDescription: String {
    let cachedCustomerInfo = Purchases.shared.cachedCustomerInfo?.id ?? ""
    let debugInfo =
      "BookPlayer \(appVersion)\(versionSuffix)\n\(Device.current)\(systemVersion)\n\n\(cachedCustomerInfo)"
    return "settings_support_compose_description".localized + " \(supportEmail).\n\n\(debugInfo)"
  }

  private var debugInfo: String {
    let cachedCustomerInfo = Purchases.shared.cachedCustomerInfo?.id ?? ""
    let debugInfo =
      "BookPlayer \(appVersion)\(versionSuffix)\n\(Device.current)\(systemVersion)\n\n\(cachedCustomerInfo)"
    return "\(supportEmail)\n\n\(debugInfo)"
  }

  private var appVersion: String {
    let version =
      Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
      ?? "0.0.0"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"

    return "\(version)-\(build)"
  }

  private var systemVersion: String {
    return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
  }
}

#Preview {
  SettingsView()
}
