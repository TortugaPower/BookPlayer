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
      NavigationLink(value: ProfileScreen.listeningHistory) {
        VStack {
          Text(formattedListeningTime)
            .bpFont(.title)
          Text("total_listening_title")
            .bpFont(.subheadline)
            .foregroundStyle(theme.secondaryColor)
          Text("listening_history_title")
            .bpFont(.caption)
            .foregroundStyle(theme.linkColor)
            .padding(.top, 4)
        }
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity)
      }
      .listRowBackground(Color.clear)
    }
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
    let audioMetadataService = AudioMetadataService()
    libraryService.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)

    return libraryService
  }()

  NavigationStack {
    Form {
      ProfileListenedSectionView()
    }
    .navigationDestination(for: ProfileScreen.self) { destination in
      if destination == .listeningHistory {
        Text("Listening History")
      }
    }
  }
  .environmentObject(ThemeViewModel())
  .environment(\.accountService, accountService)
  .environment(\.libraryService, libraryService)
}
