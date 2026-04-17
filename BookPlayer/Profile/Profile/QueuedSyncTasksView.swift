//
//  QueuedSyncTasksView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 26/5/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftData
import SwiftUI

struct QueuedSyncTasksView: View {
  @AppStorage(Constants.UserDefaults.allowCellularData)
  private var allowsCellularData: Bool = false
  @State private var queuedJobs = [SyncTaskReference]()
  @State private var jobsCount = 0
  @State private var showInfoAlert = false
  @State private var networkMonitor = NetworkMonitor()

  @Environment(\.syncService) private var syncService
  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    List {
      ThemedSection {
        if queuedJobs.isEmpty {
          // MARK: - Empty State
          VStack(spacing: 12) {
            Image(systemName: "checkmark.icloud")
              .font(.system(size: 40))
              .foregroundStyle(.secondary)
            
            Text("No queued tasks")
              .font(.headline)
            
            Text("All your sync tasks are up to date.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
          .padding(.vertical, 40)
          .frame(maxWidth: .infinity)
          .listRowBackground(Color.clear)
          
        } else {
          ForEach(queuedJobs) { job in
            QueuedSyncTaskRowView(
              imageName: .constant(parseImageName(job.jobType)),
              title: job.jobType == .matchUuid ? .constant("sync_library_title".localized) : .constant(job.relativePath),
              relativePath: job.uuid,
              initialProgress: job.jobType == .upload ? job.progress : 0,
              isUpload: job.jobType == .upload
            )
          }
        }
      } header: {
        if !allowsCellularData && !networkMonitor.isConnectedViaWiFi {
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
      }
    }
    .scrollContentBackground(.hidden)
    .background(theme.systemBackgroundColor)
    .toolbarColorScheme(theme.useDarkVariant ? .dark : .light, for: .navigationBar)
    .navigationTitle("tasks_title")
    .navigationBarTitleDisplayMode(.inline)
    .alert("", isPresented: $showInfoAlert) {
      Button("ok_button", role: .cancel) {}
        .foregroundStyle(theme.linkColor)
    } message: {
      Text("sync_tasks_alert_description")
    }
    .onReceive(
      syncService.observeTasksCount()
      .dropFirst()
    ) { count in
      guard jobsCount != count else { return }

      jobsCount = count
      reloadQueuedJobs()
    }
    .onAppear {
      reloadQueuedJobs()
    }
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button {
          showInfoAlert = true
        } label: {
          Image(systemName: "info.circle")
        }
        .foregroundStyle(theme.linkColor)
      }
    }
  }

  func reloadQueuedJobs() {
    Task { @MainActor in
      let allJobs = await syncService.getAllQueuedJobs()
      jobsCount = allJobs.count
      queuedJobs = allJobs
    }
  }

  func parseImageName(_ jobType: SyncJobType) -> String {
    switch jobType {
    case .upload:
      return "arrow.up.to.line"
    case .update:
      return "arrow.2.circlepath"
    case .move:
      return "arrow.forward"
    case .renameFolder:
      return "square.and.pencil"
    case .delete:
      return "xmark.bin.fill"
    case .shallowDelete:
      return "xmark.bin"
    case .setBookmark:
      return "bookmark"
    case .deleteBookmark:
      return "bookmark.slash"
    case .uploadArtwork:
      return "photo"
    case .matchUuid:
      return "app.connected.to.app.below.fill"
    case .externalResource:
      return "arrow.up.forward.square"
    }
  }
}
