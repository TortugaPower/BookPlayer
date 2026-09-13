//
//  ProfileSyncTasksSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 31/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftData
import SwiftUI

struct ProfileSyncTasksSectionView: View {
  @State private var statusMessage: String = ""
  /// Every lane, summed by the engine that owns them all
  @State private var queuedCount = 0

  private var buttonText: String {
    String(format: "queued_sync_tasks_title".localized, queuedCount)
  }

  @Environment(\.concurrenceService) private var concurrenceService
  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    NavigationLink(value: ProfileScreen.queueTasks) {
      VStack {
        Text(buttonText)
          .bpFont(.body)
          .foregroundStyle(theme.linkColor)
        Text(statusMessage)
          .bpFont(.caption)
          .foregroundStyle(theme.secondaryColor)
      }
    }
    .onReceive(concurrenceService.observeQueueCounts()) { counts in
      guard queuedCount != counts.total else { return }

      queuedCount = counts.total
    }
    .onReceive(
      NotificationCenter.default.publisher(for: .uploadProgressUpdated)
        .receive(on: DispatchQueue.main)
    ) { notification in
      guard
        let relativePath = notification.userInfo?["relativePath"] as? String,
        let progress = notification.userInfo?["progress"] as? Double
      else { return }
      self.updateSyncMessage(relativePath: relativePath, progress: progress)
    }
    .onReceive(
      NotificationCenter.default.publisher(for: .uploadCompleted)
        .receive(on: DispatchQueue.main)
    ) { _ in
      self.statusMessage = ""
    }
    .onAppear {
      refreshSyncStatusMessage()
    }
  }

  func updateSyncMessage(relativePath: String, progress: Double) {
    statusMessage = "\(Int(round(progress * 100)))% \(relativePath)"
  }

  func refreshSyncStatusMessage() {
    let timestamp = UserDefaults.standard.double(forKey: "\(Constants.UserDefaults.lastSyncTimestamp)_library")

    guard timestamp > 0 else { return }

    let storedDate = Date(timeIntervalSince1970: timestamp)

    let timeDifference = Date().timeIntervalSince(storedDate)

    guard
      let formattedTime = formatTime(timeDifference, units: [.day, .hour, .minute, .second])
    else { return }

    statusMessage = String(format: "last_sync_title".localized, formattedTime)
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

// Environment defaults are un-setup() placeholders whose count methods trap (see
// CLAUDE.md's DI section) — previews must construct + setup() + inject.
#Preview {
  @Previewable var concurrenceService: ConcurrenceService = {
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: ""))
    let audioMetadataService = AudioMetadataService()
    let libraryService = LibraryService()
    libraryService.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)
    let accountService = AccountService()
    accountService.setup(dataManager: dataManager)
    let concurrenceService = ConcurrenceService()
    concurrenceService.setup(
      libraryService: libraryService,
      getAccessLevel: { accountService.getAccessLevel() },
      tasksDataManager: TasksDataManager(),
      networkClient: NetworkClient(),
      dataManager: dataManager
    )

    return concurrenceService
  }()

  ProfileSyncTasksSectionView()
    .environmentObject(ThemeViewModel())
    .environment(\.concurrenceService, concurrenceService)
}
