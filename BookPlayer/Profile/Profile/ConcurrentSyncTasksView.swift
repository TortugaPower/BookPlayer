//
//  ConcurrentSyncTasksView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 24/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftData
import SwiftUI

struct ConcurrentSyncTasksView: View {
  @AppStorage(Constants.UserDefaults.allowCellularData)
  private var allowsCellularData: Bool = false
  var monitor = ConcurrentTaskProgressMonitor.shared
  @State private var queuedJobs = [ConcurrentSyncTask]()
  @State private var jobsCount = 0
  @State private var showInfoAlert = false
  @State private var networkMonitor = NetworkMonitor()

  @Environment(\.concurrenceService) private var concurrenceService
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
              title: .constant(parseLabel(job.jobType, job.queueKey)),
              relativePath: "",
              initialProgress: monitor.getTaskProgress(taskID: job.id),
              isUpload: false
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
    .navigationTitle("Concurrent Tasks")
    .navigationBarTitleDisplayMode(.inline)
    .alert("", isPresented: $showInfoAlert) {
      Button("ok_button", role: .cancel) {}
        .foregroundStyle(theme.linkColor)
    } message: {
      Text("sync_tasks_alert_description")
    }
    .onReceive(
      concurrenceService.observeConcurrentTasksCount()
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
      let allJobs = await concurrenceService.getOrderedQueuedJobs(activeTasks: monitor.activeTasks)
      jobsCount = allJobs.count
      queuedJobs = allJobs
    }
  }

  func parseImageName(_ jobType: ExternalSyncJobType) -> String {
    switch jobType {
    case .update:
      return "arrow.2.circlepath"
    case .uploadFile:
      return "square.and.arrow.up.badge.clock"
    }
  }
  
  func parseLabel(_ jobType: ExternalSyncJobType, _ queueKey: String) -> String {
    switch jobType {
    case .update:
      return "Updating progress for \(queueKey)"
    case .uploadFile:
      return "Uploading file"
    }
  }
}
