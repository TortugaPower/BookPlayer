//
//  SettingsSupportSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import MessageUI
import RevenueCat
import SwiftUI
import UniformTypeIdentifiers

struct SettingsSupportSectionView: View {
  var accessLevel: AccessLevel
  @EnvironmentObject var theme: ThemeViewModel
  @Environment(\.libraryService) private var libraryService
  @Environment(\.accountService) private var accountService
  @Environment(\.syncService) private var syncService
  @Environment(\.loadingState) private var loadingState
  @Environment(\.openURL) private var openURL

  @State private var isExportingDebugFile = false
  @State private var debugDocument: DebugFileDocument?

  let supportEmail = "support@bookplayer.app"

  var sendEmail: () -> Void

  var body: some View {
    ThemedSection {
      NavigationLink(value: SettingsScreen.tipjar) {
        Text("settings_tip_jar_title")
          .bpFont(.body)
      }
      Button(action: sendEmail) {
        VStack(alignment: .leading) {
          Text("settings_support_email_title")
            .bpFont(.body)
            .foregroundStyle(theme.primaryColor)
          Text(verbatim: supportEmail)
            .bpFont(.subheadline)
            .foregroundStyle(theme.secondaryColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.borderless)

      debugInfoButton
      Button {
        let url = URL(string: "https://github.com/TortugaPower/BookPlayer")!
        openURL(url)
      } label: {
        Text("settings_support_project_title")
          .bpFont(.body)
      }
      .foregroundStyle(theme.primaryColor)
      Button {
        let url = URL(string: "https://discord.gg/RPPyhyMPXW")!
        openURL(url)
      } label: {
        Text("settings_support_discord_title")
          .bpFont(.body)
      }
      .foregroundStyle(theme.primaryColor)
    } header: {
      Text("settings_support_title")
        .bpFont(.subheadline)
        .foregroundStyle(theme.secondaryColor)
    } footer: {
      Text("BookPlayer \(appVersion) - \(systemVersion)")
        .bpFont(.caption)
        .foregroundStyle(theme.secondaryColor)
    }
  }

  @ViewBuilder
  private var debugInfoButton: some View {
    let file = DebugFileTransferable(
      libraryService: libraryService,
      accountService: accountService,
      syncService: syncService
    )
    // On iOS-app-on-Mac, `ShareLink` + `Transferable` crashes in
    // `SHKSaveToFilesSharingService` when routing to "Save to Files" because
    // `NSItemProvider.suggestedName` isn't propagated, and `NSSavePanel`
    // rejects the nil filename. Use `.fileExporter` with an explicit
    // `defaultFilename` to bypass that path.
    if ProcessInfo.processInfo.isiOSAppOnMac {
      Button {
        Task {
          loadingState.show = true
          let data = await file.generateDebugData()
          loadingState.show = false
          debugDocument = DebugFileDocument(data: data)
          isExportingDebugFile = true
        }
      } label: {
        Text("settings_share_debug_information")
          .bpFont(.body)
      }
      .foregroundStyle(theme.primaryColor)
      .fileExporter(
        isPresented: $isExportingDebugFile,
        document: debugDocument,
        contentType: .plainText,
        defaultFilename: "bookplayer_debug_information"
      ) { _ in
        debugDocument = nil
      }
    } else {
      ShareLink(
        item: file,
        preview: SharePreview(
          "bookplayer_debug_information.txt",
          image: Image(systemName: "text.page")
        )
      ) {
        Text("settings_share_debug_information")
          .bpFont(.body)
      }
      .foregroundStyle(theme.primaryColor)
    }
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
  NavigationStack {
    Form {
      SettingsSupportSectionView(accessLevel: .pro) {
      }
    }
  }
  .environmentObject(ThemeViewModel())
}
