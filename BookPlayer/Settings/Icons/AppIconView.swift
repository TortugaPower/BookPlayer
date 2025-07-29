//
//  AppIconView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import WidgetKit

struct AppIconView: View {
  @AppStorage(Constants.UserDefaults.appIcon, store: UserDefaults(suiteName: Constants.ApplicationGroupIdentifier))
  var appIcon: String = "Default"

  let icon: Icon

  @Environment(\.accountService) private var accountService
  @Environment(\.loadingOverlay) private var loadingOverlay
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Button {
      Task {
        do {
          try await updateAppIcon(icon.title)
        } catch {
          self.loadingOverlay.error = error
        }
      }
    } label: {
      HStack(spacing: Spacing.S) {
        Image(uiImage: UIImage(named: icon.imageName)!)
          .resizable()
          .frame(width: 57, height: 57)
          .mask {
            RoundedRectangle(cornerRadius: 8)
          }
          .padding(.vertical, Spacing.S3)

        VStack(alignment: .leading) {
          Text(icon.title)
            .bpFont(Fonts.title)
            .foregroundStyle(theme.primaryColor)
          Text(icon.author)
            .bpFont(Fonts.caption)
            .foregroundStyle(theme.secondaryColor)
        }

        Spacer()

        if appIcon == icon.title {
          Image(systemName: "checkmark")
            .foregroundColor(theme.linkColor)
        } else if icon.isLocked && accountService.accessLevel == .free {
          Image(.premiumFeature)
            .foregroundColor(theme.linkColor)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabledWithOpacity(icon.isLocked && accountService.accessLevel == .free, opacity: 0.99)
  }

  func updateAppIcon(_ iconName: String) async throws {
    guard UIApplication.shared.supportsAlternateIcons else {
      throw "icon_error_description".localized
    }

    appIcon = iconName

    let icon = iconName == "Default" ? nil : iconName

    try await UIApplication.shared.setAlternateIconName(icon)
    WidgetCenter.shared.reloadAllTimelines()
  }
}
