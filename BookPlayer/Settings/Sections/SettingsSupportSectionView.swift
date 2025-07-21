//
//  SettingsSupportSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import MessageUI
import RevenueCat
import SwiftUI

struct SettingsSupportSectionView: View {
  @Binding var accessLevel: AccessLevel
  @EnvironmentObject var theme: ThemeViewModel

  let supportEmail = "support@bookplayer.app"

  var shareDebugInformation: () -> Void
  var sendEmail: () -> Void

  var body: some View {
    Section {
      NavigationLink("settings_tip_jar_title", value: SettingsScreen.tipjar)
      Button(action: sendEmail) {
        VStack(alignment: .leading) {
          Text("settings_support_email_title")
            .foregroundColor(theme.primaryColor)
          Text(verbatim: supportEmail)
            .font(.subheadline)
            .foregroundColor(theme.secondaryColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.borderless)
      Button("settings_share_debug_information") {
        shareDebugInformation()
      }
      .foregroundColor(theme.primaryColor)
      Button("settings_support_project_title") {
        handleOpenGithub()
      }
      .foregroundColor(theme.primaryColor)
    } header: {
      Text("settings_support_title")
        .foregroundColor(theme.secondaryColor)
    } footer: {
      Text("BookPlayer \(appVersion) - \(systemVersion)")
        .foregroundColor(theme.secondaryColor)
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

  func handleOpenGithub() {
    let url = URL(string: "https://github.com/TortugaPower/BookPlayer")!
    UIApplication.shared.open(url)
  }
}

#Preview {
  NavigationStack {
    Form {
      SettingsSupportSectionView(accessLevel: .constant(.pro)) {
      } sendEmail: {
      }
    }
  }
  .environmentObject(ThemeViewModel())
}
