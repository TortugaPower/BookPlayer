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
  @State private var tasks = [ConcurrentSyncTask]()
  @State private var counts = QueueCounts()
  /// Stored inverted on purpose: a lane that appears while the screen is open starts expanded
  @State private var collapsedLanes = Set<String>()
  @State private var showInfoAlert = false
  @State private var networkMonitor = NetworkMonitor()
  var monitor = ConcurrentTaskProgressMonitor.shared

  @Environment(\.concurrenceService) private var concurrenceService
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
    .navigationTitle("queued_tasks_title".localized)
    .navigationBarTitleDisplayMode(.inline)
    .alert("", isPresented: $showInfoAlert) {
      Button("ok_button".localized, role: .cancel) {}
    } message: {
      Text("sync_tasks_alert_description".localized)
    }
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button {
          showInfoAlert = true
        } label: {
          Image(systemName: "info.circle")
        }
        .accessibilityLabel("info_title".localized)
        .foregroundStyle(theme.linkColor)
      }
    }
    // Replays the current snapshot on subscribe, so this is the initial load as well.
    .onReceive(concurrenceService.observeQueueCounts()) { snapshot in
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
      Text("upload_wifi_required_title".localized)
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

      Text("sync_tasks_empty_title".localized)
        .bpFont(.headline)

      Text("sync_tasks_empty_description".localized)
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
      tasks = await concurrenceService.getOrderedQueuedJobs(activeTaskIDs: Set(monitor.activeTasks.keys))
    }
  }
}

// MARK: - Preview
// Environment defaults are un-setup() placeholders whose count methods trap (see
// CLAUDE.md's DI section) — previews must construct + setup() + inject, same as
// ProfileSyncTasksSectionView's preview.
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

  NavigationStack {
    QueuedTasksView()
  }
  .environmentObject(ThemeViewModel())
  .environment(\.concurrenceService, concurrenceService)
}
