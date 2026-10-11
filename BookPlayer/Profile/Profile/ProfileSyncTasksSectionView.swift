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
  /// Parked tasks across every lane: the title turns into a warning while any need the user
  @State private var pausedCount = 0

  private var buttonText: String {
    String(format: "queued_sync_tasks_title".localized, queuedCount)
  }

  @Environment(\.syncQueueService) private var syncQueueService
  @Environment(\.uploadContinuation) private var uploadContinuation
  @Environment(\.scenePhase) private var scenePhase
  /// Read so the button follows the setting (the offer checks it, but can't observe it)
  @AppStorage(Constants.UserDefaults.allowCellularData) private var allowsCellularData = false
  @EnvironmentObject private var theme: ThemeViewModel

  /// The offer checks the cellular setting through a closure SwiftUI can't observe: reading
  /// the setting here makes the button follow it
  private var showsContinueButton: Bool {
    _ = allowsCellularData
    return uploadContinuation.isOfferAvailable
  }

  /// While the continued task runs, its progress replaces the sync status
  private var caption: String {
    if uploadContinuation.state == .running, let percent = uploadContinuation.runningPercent {
      return String(format: "uploads_running_background_caption".localized, percent)
    }
    return statusMessage
  }

  var body: some View {
    VStack(spacing: Spacing.S2) {
      queuedTasksLink
      if showsContinueButton {
        Button {
          uploadContinuation.continueInBackground()
        } label: {
          Text("continue_uploads_background_button")
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .bpFont(.subheadline)
        .foregroundStyle(theme.linkColor)
      }
    }
    .task { await uploadContinuation.refreshState() }
    // iOS may drop the request while the app is away
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      Task { await uploadContinuation.refreshState() }
    }
  }

  private var queuedTasksLink: some View {
    NavigationLink(value: ProfileScreen.queueTasks) {
      VStack {
        HStack(spacing: Spacing.S4) {
          if pausedCount > 0 {
            Image(systemName: "exclamationmark.triangle.fill")
              .accessibilityHidden(true)
          }
          Text(buttonText)
        }
        .bpFont(.body)
        .foregroundStyle(pausedCount > 0 ? .red : theme.linkColor)
        Text(caption)
          .bpFont(.caption)
          .foregroundStyle(theme.secondaryColor)
      }
      // Not by colour alone: VoiceOver hears it too
      .accessibilityElement(children: .combine)
      .accessibilityValue(pausedCount > 0 ? "sync_tasks_need_attention_voiceover".localized : "")
    }
    // Once while the section is up: `observeQueueCounts()` is a new publisher on every call, so
    // `.onReceive` subscribed again (and took a replayed snapshot) on every render
    .task {
      for await counts in syncQueueService.observeQueueCounts().values {
        queuedCount = counts.total
        pausedCount = counts.totalPaused
      }
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
  @Previewable var syncQueueService: SyncQueueService = {
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: ""))
    let audioMetadataService = AudioMetadataService()
    let libraryService = LibraryService()
    libraryService.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)
    let accountService = AccountService()
    accountService.setup(dataManager: dataManager)
    let syncQueueService = SyncQueueService()
    syncQueueService.setup(
      libraryService: libraryService,
      getAccessLevel: { accountService.getAccessLevel() },
      verifyAccessLevel: { nil },
      tasksDataManager: TasksDataManager(),
      networkClient: NetworkClient(),
      dataManager: dataManager
    )

    return syncQueueService
  }()

  ProfileSyncTasksSectionView()
    .environmentObject(ThemeViewModel())
    .environment(\.syncQueueService, syncQueueService)
}
