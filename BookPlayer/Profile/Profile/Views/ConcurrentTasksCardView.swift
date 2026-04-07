//
//  TasksReviewCardView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 31/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import BookPlayerKit
import SwiftData

struct ConcurrentTasksCardView: View {
  var monitor = ConcurrentTaskProgressMonitor.shared
  @State private var queuedJobs = [ConcurrentSyncTask]()
  @State private var jobsCount = 0
  
  @Environment(\.concurrenceService) private var concurrenceService
  @EnvironmentObject private var theme: ThemeViewModel
  
  var body: some View {
    HStack {
      
      VStack(alignment: .leading, spacing: 6) {
        Text("Concurrent Tasks (\(jobsCount))")
          .bpFont(.titleRegular)
          .foregroundStyle(theme.primaryColor)
        
        if let job = queuedJobs.first {
          Text("\(parseLabel(job.jobType, job.queueKey))")
            .bpFont(.subheadline)
            .foregroundStyle(theme.secondaryColor)
        } else {
          Text("No running tasks")
            .bpFont(.subheadline)
            .foregroundStyle(theme.secondaryColor)
        }
      }
      
      Spacer()
      
      if let job = queuedJobs.first {
        let progress = monitor.getTaskProgress(taskID: job.id)
        
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
      concurrenceService.observeConcurrentTasksCount()
    ) { count in
      guard jobsCount != count else { return }

      jobsCount = count
      reloadQueuedJobs()
    }
    .onAppear {
      reloadQueuedJobs()
    }
  }
  
  func reloadQueuedJobs() {
    Task { @MainActor in
      let allJobs = await concurrenceService.getOrderedQueuedJobs(activeTasks: monitor.activeTasks)
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
}

// MARK: - Preview
struct ConcurrentTasksCardView_Previews: PreviewProvider {
  static var previews: some View {
    ZStack {
      Color(.secondarySystemBackground).edgesIgnoringSafeArea(.all)
      ConcurrentTasksCardView()
    }
  }
}
