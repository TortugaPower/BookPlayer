//
//  SyncTasksCardView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 31/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import BookPlayerKit
import SwiftData

struct SyncTasksCardView: View {
  @AppStorage(Constants.UserDefaults.allowCellularData)
  private var allowsCellularData: Bool = false
  @State private var queuedJobs = [SyncTaskReference]()
  @State private var jobsCount = 0
  @State private var showInfoAlert = false
  @State private var networkMonitor = NetworkMonitor()
  @State private var statusMessage = ""

  @Environment(\.syncService) private var syncService
  @EnvironmentObject private var theme: ThemeViewModel
  
  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 6) {
        Text("Queued sync tasks (\(jobsCount))")
          .bpFont(.titleRegular)
          .foregroundStyle(theme.primaryColor)
        
        Text(statusMessage)
          .bpFont(.subheadline)
          .foregroundStyle(theme.secondaryColor)
      }
      
      Spacer()
      
      if let job = queuedJobs.first {
        let progress = job.jobType == .upload ? job.progress : 0
        
        if progress == 0 {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
        } else {
          CircularProgressView(
            progress: progress,
            isHighlighted: true
          )
        }
      }
    }
    .padding(16)
    .background(theme.tertiarySystemBackgroundColor)
    .cornerRadius(16)
    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    .padding(.horizontal)
    .onReceive(
      syncService.observeTasksCount()
      .dropFirst()
    ) { count in
      guard jobsCount != count else { return }

      jobsCount = count
      reloadQueuedJobs()
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
      reloadQueuedJobs()
      refreshSyncStatusMessage()
    }
  }
  
  func reloadQueuedJobs() {
    Task { @MainActor in
      let allJobs = await syncService.getAllQueuedJobs()
      jobsCount = allJobs.count
      queuedJobs = allJobs
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

// MARK: - Preview
struct SyncTasksCardView_Previews: PreviewProvider {
  static var previews: some View {
    ZStack {
      Color(.secondarySystemBackground).edgesIgnoringSafeArea(.all)
      SyncTasksCardView()
    }
  }
}
