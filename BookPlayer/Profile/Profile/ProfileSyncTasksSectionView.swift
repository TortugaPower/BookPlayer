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
  @State private var jobsCount = 0
  @State private var concurrentJobsCount = 0

  private var buttonText: String {
    String(format: "queued_sync_tasks_title".localized, jobsCount + concurrentJobsCount)
  }

  @Environment(\.syncService) private var syncService
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
    .onReceive(syncService.observeTasksCount()) { count in
      guard jobsCount != count else { return }

      jobsCount = count
    }
    .onReceive(concurrenceService.observeConcurrentTasksCount()) { count in
      guard concurrentJobsCount != count else { return }

      concurrentJobsCount = count
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

#Preview {
  @Previewable var syncService: SyncService = {
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: ""))
    let audioMetadataService = AudioMetadataService()
    let libraryService = LibraryService()
    libraryService.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)
    let syncService = SyncService()
    syncService.setup(isActive: true, libraryService: libraryService, dataManager: dataManager)

    return syncService
  }()

  ProfileSyncTasksSectionView()
    .environmentObject(ThemeViewModel())
    .environment(\.syncService, syncService)
}
