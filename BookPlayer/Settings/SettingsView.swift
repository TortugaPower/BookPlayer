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
  /// The screen shown beside the list, or pushed over it on iPhone
  @State private var selection: SettingsScreen?
  /// Too narrow for the list beside a screen, like iPhone Duo open in portrait (669 pt): the
  /// split view would hide the list behind its sidebar button, leaving an empty screen
  @State private var isTooNarrowForSplit = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
  @Environment(\.audiobookshelfService) private var audiobookshelfService
  @Environment(\.hardcoverService) private var hardcoverService
  @Environment(\.playerState) private var playerState
  @EnvironmentObject private var theme: ThemeViewModel

  let supportEmail = "support@bookplayer.app"

  var body: some View {
    /// The list beside the screen it opens on a wide screen, like iPad or iPhone Duo open (in book
    /// pose the two sides meet at the fold); collapsed into one stack on iPhone, as before
    NavigationSplitView {
      /// A list rather than a form: its selection is what the links set, which highlights the
      /// screen shown beside it
      List(selection: $selection) {
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
      /// As the form looked: in a split view's first column a list defaults to the sidebar style
      .listStyle(.insetGrouped)
      .environment(\.selectedSettingsScreen, selection)
      .navigationTitle("settings_title")
      .navigationBarTitleDisplayMode(.inline)
      .applyListStyle(with: theme, background: theme.systemBackgroundColor)
      .miniPlayerSafeAreaInset()
    } detail: {
      NavigationStack {
        if let selection {
          destination(for: selection)
            .id(selection)
        } else {
          ContentUnavailableView("settings_title", systemImage: "gearshape")
            .background(theme.systemBackgroundColor)
        }
      }
    }
    /// Collapsed into one stack instead, list first, as on iPhone
    .environment(\.horizontalSizeClass, isTooNarrowForSplit ? .compact : horizontalSizeClass)
    .onGeometryChange(for: Bool.self) { $0.size.width < 700 } action: { isTooNarrowForSplit = $0 }
    /// Up to the top of the screen, as a navigation stack would: the columns' content then scrolls
    /// behind the status bar too, while their bars still sit below it
    .ignoresSafeArea(.container, edges: .top)
    /// Behind the columns too: the split view's own area (under the status bar and, on iPad, the
    /// tab bar) would show the system background instead of the theme's
    .background(theme.systemBackgroundColor.ignoresSafeArea())
    .environment(\.loadingState, loadingState)
    .loadingOverlay(loadingState.show)
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
    .sheet(isPresented: $showLogin) {
      NavigationStack {
        LoginView()
      }
    }
    .sheet(isPresented: $showCompleteAccount) {
      SettingsCompleteAccountView()
        .presentationDetents([.medium])
    }
    .foregroundStyle(theme.primaryColor)
    .tint(theme.linkColor)
  }

  private func destination(for destination: SettingsScreen) -> some View {
    let view: AnyView
    switch destination {
    case .themes:
      view = AnyView(SettingsThemesView())
    case .icons:
      view = AnyView(SettingsAppIconsView())
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
    case .mediaServers:
      view = AnyView(
        MediaServersView(
          jellyfinService: jellyfinService,
          audiobookshelfService: audiobookshelfService,
          style: .settings
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
    case .lite:
      return "l"
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
