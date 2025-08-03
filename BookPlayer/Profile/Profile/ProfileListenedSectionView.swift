//
//  ProfileListenedSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 31/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ProfileListenedSectionView: View {
  @State private var formattedListeningTime: String = ""

  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.libraryService) private var libraryService
  var body: some View {
    Section {
      VStack {
        Text(formattedListeningTime)
          .font(Font(Fonts.title))
        Text("total_listening_title".localized)
          .font(Font(Fonts.subheadline))
          .foregroundStyle(theme.secondaryColor)
      }
      .accessibilityElement(children: .combine)
      .frame(maxWidth: .infinity)
    }
    .listRowBackground(Color.clear)
    .onReceive(NotificationCenter.default.publisher(for: .bookPaused)) { _ in
      reloadListeningTime()
    }
    .onAppear {
      reloadListeningTime()
    }
  }

  func reloadListeningTime() {
    let time = libraryService.getTotalListenedTime()
    
    guard let formattedTime = formatTime(time) else { return }
    
    formattedListeningTime = formattedTime
  }

  func formatTime(
    _ time: Double,
    units: NSCalendar.Unit = [.year, .day, .hour, .minute]
  ) -> String? {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = units
    formatter.unitsStyle = .abbreviated

    return formatter.string(from: time)
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

  @Previewable var libraryService: LibraryService = {
    let libraryService = LibraryService()
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: ""))
    libraryService.setup(dataManager: dataManager)

    return libraryService
  }()

  Form {
    ProfileListenedSectionView()
  }
  .environmentObject(ThemeViewModel())
  .environment(\.accountService, accountService)
  .environment(\.libraryService, libraryService)
}
