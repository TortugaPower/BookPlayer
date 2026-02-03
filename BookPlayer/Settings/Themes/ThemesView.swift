//
//  ThemesView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ThemesView: View {
  let item: SimpleTheme

  @Environment(\.accountService) private var accountService
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Button {
      ThemeManager.shared.currentTheme = item
    } label: {
      HStack(spacing: Spacing.S1) {
        ThemeShowcaseView(theme: item)

        Text(item.title)
          .bpFont(.title)
          .foregroundStyle(theme.primaryColor)

        Spacer()

        if item == ThemeManager.shared.currentTheme {
          Image(systemName: "checkmark")
            .foregroundColor(theme.linkColor)
        } else if item.locked && accountService.accessLevel == .free {
          Image(.premiumFeature)
            .foregroundColor(theme.linkColor)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabledWithOpacity(item.locked && accountService.accessLevel == .free, opacity: 0.99)
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

  ThemesView(item: .getDefaultTheme())
    .environmentObject(ThemeViewModel())
    .environment(\.accountService, accountService)
}

struct ThemeShowcaseView: View {
  let theme: SimpleTheme

  var body: some View {
    ZStack {
      MaskedLayer(maskName: "themeColorBackgroundMask", color: theme.lightSystemBackgroundColor)
      MaskedLayer(maskName: "themeColorAccentMask", color: theme.lightLinkColor)
      MaskedLayer(maskName: "themeColorPrimaryMask", color: theme.lightPrimaryColor)
      MaskedLayer(maskName: "themeColorSecondaryMask", color: theme.lightSecondaryColor)
    }
    .clipped()
    .frame(width: 44, height: 44)
  }
}

struct MaskedLayer: View {
  let maskName: String
  let color: UIColor

  var body: some View {
    Color(color)
      .mask(
        Image(maskName)
          .resizable()
          .scaledToFit()  // Or use .aspectRatio(contentMode: .fill) depending on your design
      )
  }
}
