//
//  QueuedTasksView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 31/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import BookPlayerKit
import SwiftData

/// Display metadata for a task queue key
enum QueueDisplay {
  static func name(for queueKey: String) -> String {
    switch queueKey {
    case TaskQueueKey.sync:
      return "queue_library_sync_title".localized
    case TaskQueueKey.uploadFile:
      return "queue_file_uploads_title".localized
    default:
      return queueKey.capitalized
    }
  }

  static func imageName(for queueKey: String) -> String {
    switch queueKey {
    case TaskQueueKey.sync:
      return "arrow.triangle.2.circlepath.icloud"
    case TaskQueueKey.uploadFile:
      return "square.and.arrow.up.badge.clock"
    default:
      return "antenna.radiowaves.left.and.right"
    }
  }
}

/// Overview of the active task queues; each row navigates to that queue's tasks
struct QueuedTasksView: View {
  @State private var queues = [QueueSummary]()

  @Environment(\.syncService) private var syncService
  @Environment(\.concurrenceService) private var concurrenceService
  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    List {
      ThemedSection {
        ForEach(queues) { queue in
          NavigationLink(value: ProfileScreen.queue(queue.queueKey)) {
            HStack(spacing: Spacing.S1) {
              Image(systemName: QueueDisplay.imageName(for: queue.queueKey))
                .frame(width: 24)
                .foregroundStyle(theme.linkColor)
              Text(QueueDisplay.name(for: queue.queueKey))
                .bpFont(.body)
              Spacer()
              Text("\(queue.count)")
                .bpFont(.subheadline)
                .foregroundStyle(theme.secondaryColor)
            }
            .padding(.vertical, Spacing.S3)
          }
          .listRowBackground(theme.tertiarySystemBackgroundColor)
        }
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(theme.systemBackgroundColor)
    .toolbarColorScheme(theme.useDarkVariant ? .dark : .light, for: .navigationBar)
    .navigationTitle("Queued Tasks")
    .navigationBarTitleDisplayMode(.inline)
    .onReceive(syncService.observeTasksCount()) { _ in
      reloadQueues()
    }
    .onReceive(concurrenceService.observeConcurrentTasksCount()) { _ in
      reloadQueues()
    }
    .onAppear {
      reloadQueues()
    }
  }

  func reloadQueues() {
    Task { @MainActor in
      queues = await concurrenceService.getQueueSummaries()
    }
  }
}

// MARK: - Preview
struct QueuedTasksView_Previews: PreviewProvider {
  static var previews: some View {
    ZStack {
      Color(.secondarySystemBackground).edgesIgnoringSafeArea(.all)
      QueuedTasksView()
    }
  }
}
