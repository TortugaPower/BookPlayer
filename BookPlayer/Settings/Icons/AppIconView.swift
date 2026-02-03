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
  @Environment(\.loadingState) private var loadingState
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Button {
      Task {
        do {
          try await updateAppIcon(icon)
        } catch {
          self.loadingState.error = error
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
            .bpFont(.title)
            .foregroundStyle(theme.primaryColor)
          Text(icon.author)
            .bpFont(.caption)
            .foregroundStyle(theme.secondaryColor)
        }

        Spacer()

        if appIcon == icon.id {
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

  func updateAppIcon(_ icon: Icon) async throws {
    guard UIApplication.shared.supportsAlternateIcons else {
      throw "icon_error_description".localized
    }

    appIcon = icon.title

    let icon = icon.id == "Default" ? nil : icon.id

    try await UIApplication.shared.setAlternateIconName(icon)
    WidgetCenter.shared.reloadAllTimelines()
  }
}
