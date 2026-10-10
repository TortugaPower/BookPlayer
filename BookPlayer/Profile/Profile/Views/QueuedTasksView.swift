//
//  QueuedTasksView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 31/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import MessageUI
import SwiftUI

/// Every queued task on one screen: a collapsible section per lane (sync first, then the
/// rest alphabetically), fed by the engine that owns all of them. Pushed from Profile and
/// presented as a sheet from the library list when a refresh is blocked by queued jobs.
struct QueuedTasksView: View, BPLogger {
  @AppStorage(Constants.UserDefaults.allowCellularData)
  private var allowsCellularData: Bool = false
  @State private var tasks = [QueuedSyncTask]()
  @State private var counts = QueueCounts()
  /// Stored inverted on purpose: a lane that appears while the screen is open starts expanded
  @State private var collapsedLanes = Set<String>()
  @State private var networkMonitor = NetworkMonitor()
  /// Report's destination: Mail when it's set up, the share sheet otherwise
  @State private var reportMail: SyncPauseReportMail?
  @State private var reportShare: SyncPauseReportShare?
  /// A second tap while the report builds (or its sheet is up) is ignored
  @State private var isBuildingReport = false
  /// The list reload in flight: a newer one replaces it
  @State private var reloadTask: Task<Void, Never>?
  var monitor = SyncQueueProgressMonitor.shared

  @Environment(\.syncQueueService) private var syncQueueService
  @Environment(\.libraryService) private var libraryService
  @Environment(\.accountService) private var accountService
  @Environment(\.uploadContinuation) private var uploadContinuation
  @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var theme: ThemeViewModel

  private var sections: [QueuedTaskSection] { tasks.groupedByLane() }

  var body: some View {
    List {
      // Exactly when the Wi-Fi-only setting holds uploads back: the session for it uploads over
      // any network but cellular (wired Ethernet too), and offline Wi-Fi is still the way out
      if !allowsCellularData && !(networkMonitor.isConnected && !networkMonitor.isConnectedViaCellular) {
        Section {
          EmptyView()
        } header: {
          wifiRequiredBanner
        }
      }

      if tasks.isEmpty {
        ThemedSection {
          emptyState
        }
      } else {
        ForEach(sections) { section in
          ThemedSection {
            DisclosureGroup(isExpanded: isExpanded(section.queueKey)) {
              ForEach(section.tasks) { task in
                QueuedSyncTaskRowView(
                  imageName: .constant(task.displayImageName),
                  title: .constant(task.displayTitle),
                  progressKey: task.progressKey,
                  initialProgress: monitor.getTaskProgress(taskID: task.id),
                  isUpload: task.tracksByteProgress,
                  pause: task.pause,
                  onRetry: {
                    Task {
                      await syncQueueService.retryPausedTask(id: task.id)
                      // A user action: the unblocked uploads may now run at full speed
                      await uploadContinuation.submitIfNeeded()
                    }
                  },
                  onReport: { report(task) },
                  onDismiss: { syncQueueService.dismissPausedTask(id: task.id) }
                )
              }
            } label: {
              laneHeader(section.queueKey)
            }
            .tint(theme.linkColor)
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(theme.systemBackgroundColor)
    .toolbarColorScheme(theme.useDarkVariant ? .dark : .light, for: .navigationBar)
    .navigationTitle("queued_tasks_title")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: $reportMail) { mail in
      SettingsMailView(
        recipients: [SyncPauseReport.supportEmail],
        subject: mail.report.subject,
        messageBody: mail.report.body,
        isHTML: true,
        attachmentData: AttachmentData(
          data: Data(mail.report.text.utf8),
          mimeType: "text/plain",
          fileName: SyncPauseReport.fileName
        )
      )
    }
    .sheet(item: $reportShare) { share in
      ActivityView(activityItems: [share.fileURL])
        .presentationDetents([.medium, .large])
    }
    .task { await uploadContinuation.refreshState() }
    // iOS may drop the request while the app is away
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      Task { await uploadContinuation.refreshState() }
    }
    // Subscribed once while the screen is up, not in `.onReceive`: `observeQueueCounts()` is a
    // new publisher on every call, so `.onReceive` subscribed again on every render, the replayed
    // snapshot reloaded the list, the reload rendered again, and that looped (tens of thousands
    // of times a second, each a repository read).
    // Replays the current snapshot on subscribe, so this is the initial load as well.
    .task {
      for await snapshot in syncQueueService.observeQueueCounts().values {
        counts = snapshot
      }
    }
    // The list at most twice a second: a first sync stores its tasks one at a time, and every
    // store sends a snapshot. The replayed one still loads at once, and the last one still lands
    .task {
      for await _ in syncQueueService.observeQueueCounts()
        .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
        .values {
        reloadTasks()
      }
    }
  }

  /// The upload lane offers "Continue in background" when it can help; every other lane
  /// (and the upload lane otherwise) is the plain header
  @ViewBuilder
  private func laneHeader(_ queueKey: String) -> some View {
    if queueKey == TaskQueueKey.uploadFile, uploadContinuation.isOfferAvailable {
      // Each wording measured against the whole row, so the lane title never breaks
      // mid-word to make room for a longer button
      ViewThatFits(in: .horizontal) {
        laneHeaderRow(queueKey, continueLabel: .full)
        laneHeaderRow(queueKey, continueLabel: .short)
        laneHeaderRow(queueKey, continueLabel: .icon)
      }
    } else {
      laneHeaderRow(queueKey, continueLabel: nil)
    }
  }

  private enum ContinueLabel {
    case full, short, icon
  }

  private func laneHeaderRow(_ queueKey: String, continueLabel: ContinueLabel?) -> some View {
    let isBlocked = counts.isBlocked(queueKey)
    return HStack(spacing: Spacing.S1) {
      HStack(spacing: Spacing.S1) {
        Image(systemName: isBlocked ? "exclamationmark.triangle.fill" : QueueDisplay.imageName(for: queueKey))
          .frame(width: 24)
          .foregroundStyle(isBlocked ? .red : theme.linkColor)
        VStack(alignment: .leading, spacing: 0) {
          Text(QueueDisplay.name(for: queueKey))
            .bpFont(.headline)
            .foregroundStyle(theme.primaryColor)
          if isBlocked {
            Text("sync_paused_lane_title")
              .bpFont(.caption)
              .foregroundStyle(.red)
          }
          if queueKey == TaskQueueKey.uploadFile {
            backgroundUploadStatus
          }
        }
        Spacer()
        Text("\(counts.count(in: queueKey))")
          .bpFont(.subheadline)
          .foregroundStyle(theme.secondaryColor)
      }
      .accessibilityElement(children: .combine)
      // The button sits inside the lane's disclosure label, which VoiceOver may read as one
      // element: for VoiceOver the action is offered on the header itself
      .accessibilityActions {
        if continueLabel != nil, voiceOverEnabled {
          Button("continue_in_background_button") {
            uploadContinuation.continueInBackground()
          }
        }
      }
      if let continueLabel {
        continueButton(continueLabel)
      }
    }
    .padding(.vertical, Spacing.S3)
  }

  /// What the continued task is doing, under the lane title
  @ViewBuilder
  private var backgroundUploadStatus: some View {
    switch uploadContinuation.state {
    case .starting:
      Text("uploads_starting_title")
        .bpFont(.caption)
        .foregroundStyle(theme.secondaryColor)
    case .running:
      Text("uploads_running_background_title")
        .bpFont(.caption)
        .foregroundStyle(theme.secondaryColor)
    case .idle:
      EmptyView()
    }
  }

  private func continueButton(_ label: ContinueLabel) -> some View {
    Button {
      uploadContinuation.continueInBackground()
    } label: {
      Group {
        switch label {
        case .full:
          Text("continue_in_background_button")
        case .short:
          Text("continue_uploads_short_button")
        case .icon:
          Image(systemName: "icloud.and.arrow.up")
        }
      }
      .lineLimit(1)
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(Rectangle())
    }
    // Borderless: a plain button in the label would toggle the lane instead
    .buttonStyle(.borderless)
    .bpFont(.subheadline)
    .foregroundStyle(theme.linkColor)
    // The 44 pt target reaches into the row's padding instead of growing the header
    .padding(.vertical, -Spacing.S3)
    // Named for Voice Control in every variant (the icon's symbol name isn't usable);
    // VoiceOver uses the header's action instead
    .accessibilityLabel("continue_in_background_button")
    .accessibilityHidden(voiceOverEnabled)
  }

  private var wifiRequiredBanner: some View {
    HStack {
      Spacer()
      Image(systemName: "wifi")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 20, height: 20)
        .foregroundStyle(theme.linkColor)
        .padding([.trailing], 5)
      Text("upload_wifi_required_title")
        .bpFont(.body)
        .foregroundStyle(theme.secondaryColor)
      Spacer()
    }
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "checkmark.icloud")
        .font(.largeTitle)
        .imageScale(.large)
        .foregroundStyle(.secondary)

      Text("sync_tasks_empty_title")
        .bpFont(.headline)

      Text("sync_tasks_empty_description")
        .bpFont(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(.vertical, 40)
    .frame(maxWidth: .infinity)
    .listRowBackground(Color.clear)
  }

  private func isExpanded(_ queueKey: String) -> Binding<Bool> {
    Binding(
      get: { !collapsedLanes.contains(queueKey) },
      set: { expanded in
        if expanded {
          collapsedLanes.remove(queueKey)
        } else {
          collapsedLanes.insert(queueKey)
        }
      }
    )
  }

  private func report(_ task: QueuedSyncTask) {
    guard !isBuildingReport, reportMail == nil, reportShare == nil else { return }
    isBuildingReport = true
    Task { @MainActor in
      defer { isBuildingReport = false }
      let report = await SyncPauseReport.make(
        for: task,
        syncQueueService: syncQueueService,
        libraryService: libraryService,
        accessLevel: accountService.accessLevel
      )
      if MFMailComposeViewController.canSendMail() {
        reportMail = SyncPauseReportMail(report: report)
      } else {
        do {
          reportShare = SyncPauseReportShare(fileURL: try report.writeToTemporaryFile())
        } catch {
          Self.logger.error("Couldn't write the sync report: \(error.localizedDescription)")
        }
      }
    }
  }

  /// The latest reload wins: an older one finishing after it would show an older queue
  func reloadTasks() {
    reloadTask?.cancel()
    reloadTask = Task { @MainActor in
      let latest = await syncQueueService.getOrderedQueuedJobs(activeTaskIDs: Set(monitor.activeTasks.keys))
      guard !Task.isCancelled else { return }
      tasks = latest
    }
  }
}

private struct SyncPauseReportMail: Identifiable {
  let id = UUID()
  let report: SyncPauseReport
}

private struct SyncPauseReportShare: Identifiable {
  let id = UUID()
  let fileURL: URL
}

// MARK: - Preview
// Environment defaults are un-setup() placeholders whose count methods trap (see
// CLAUDE.md's DI section) — previews must construct + setup() + inject, same as
// ProfileSyncTasksSectionView's preview.
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

  NavigationStack {
    QueuedTasksView()
  }
  .environmentObject(ThemeViewModel())
  .environment(\.syncQueueService, syncQueueService)
}
