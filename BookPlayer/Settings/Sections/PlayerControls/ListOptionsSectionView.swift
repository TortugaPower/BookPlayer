//
//  ListOptionsSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ListOptionsSectionView: View {
  @State var selectedOption: DisplayOption
  @EnvironmentObject var theme: ThemeViewModel

  init() {
    let prefersBookmarks = UserDefaults.standard.bool(forKey: Constants.UserDefaults.playerListPrefersBookmarks)

    self._selectedOption = .init(initialValue: prefersBookmarks ? .bookmarks : .chapters)
  }

  var body: some View {
    Section {
      HStack {
        Image(systemName: "list.bullet")
          .foregroundStyle(theme.secondaryColor)
        Picker("settings_playerinterface_list_title", selection: $selectedOption) {
          ForEach(DisplayOption.allCases) { option in
            Text(option.title).tag(option)
              .foregroundStyle(theme.linkColor)
          }
        }
        .pickerStyle(.menu)
        .onChange(of: selectedOption) {
          let prefersBookmarks = selectedOption == .bookmarks

          UserDefaults.standard.set(prefersBookmarks, forKey: Constants.UserDefaults.playerListPrefersBookmarks)
        }
      }
    } footer: {
      Text("settings_playerinterface_list_description")
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

extension ListOptionsSectionView {
  enum DisplayOption: Identifiable, CaseIterable {
    var id: Self { self }
    case chapters, bookmarks

    var title: LocalizedStringKey {
      switch self {
      case .chapters:
        "chapters_title"
      case .bookmarks:
        "bookmarks_title"
      }
    }
  }
}

#Preview {
  Form {
    ListOptionsSectionView()
  }
  .environmentObject(ThemeViewModel())
}
