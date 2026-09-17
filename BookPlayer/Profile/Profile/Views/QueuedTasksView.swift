//
//  QueuedTasksView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 31/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

/// Every queued task on one screen: a collapsible section per lane (sync first, then the
/// rest alphabetically), fed by the engine that owns all of them. Pushed from Profile and
/// presented as a sheet from the library list when a refresh is blocked by queued jobs.
struct QueuedTasksView: View {
  @AppStorage(Constants.UserDefaults.allowCellularData)
  private var allowsCellularData: Bool = false
  @State private var tasks = [QueuedSyncTask]()
  @State private var counts = QueueCounts()
  /// Stored inverted on purpose: a lane that appears while the screen is open starts expanded
  @State private var collapsedLanes = Set<String>()
  @State private var showInfoAlert = false
  @State private var networkMonitor = NetworkMonitor()
  var monitor = SyncQueueProgressMonitor.shared

  @Environment(\.syncQueueService) private var syncQueueService
  @EnvironmentObject private var theme: ThemeViewModel

  private var sections: [QueuedTaskSection] { tasks.groupedByLane() }

  var body: some View {
    List {
      if !allowsCellularData && !networkMonitor.isConnectedViaWiFi {
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
                  isUpload: task.tracksByteProgress
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
    .alert("", isPresented: $showInfoAlert) {
      Button("ok_button", role: .cancel) {}
    } message: {
      Text("sync_tasks_alert_description")
    }
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button {
          showInfoAlert = true
        } label: {
          Image(systemName: "info.circle")
        }
        .accessibilityLabel("info_title")
        .foregroundStyle(theme.linkColor)
      }
    }
    // Replays the current snapshot on subscribe, so this is the initial load as well.
    .onReceive(syncQueueService.observeQueueCounts()) { snapshot in
      counts = snapshot
      reloadTasks()
    }
  }

  private func laneHeader(_ queueKey: String) -> some View {
    HStack(spacing: Spacing.S1) {
      Image(systemName: QueueDisplay.imageName(for: queueKey))
        .frame(width: 24)
        .foregroundStyle(theme.linkColor)
      Text(QueueDisplay.name(for: queueKey))
        .bpFont(.headline)
        .foregroundStyle(theme.primaryColor)
      Spacer()
      Text("\(counts.count(in: queueKey))")
        .bpFont(.subheadline)
        .foregroundStyle(theme.secondaryColor)
    }
    .padding(.vertical, Spacing.S3)
    .accessibilityElement(children: .combine)
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

  func reloadTasks() {
    Task { @MainActor in
      tasks = await syncQueueService.getOrderedQueuedJobs(activeTaskIDs: Set(monitor.activeTasks.keys))
    }
  }
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
