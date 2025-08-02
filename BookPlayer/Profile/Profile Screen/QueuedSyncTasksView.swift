//
//  QueuedSyncTasksView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 26/5/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct QueuedSyncTasksView: View {
  @AppStorage(Constants.UserDefaults.allowCellularData)
  private var allowsCellularData: Bool = false
  @State private var queuedJobs = [SyncTaskReference]()
  @State private var showInfoAlert = false

  @Environment(\.syncService) private var syncService
  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    List {
      Section {
        ForEach(queuedJobs) { job in
          QueuedSyncTaskRowView(
            imageName: .constant(parseImageName(job.jobType)),
            title: .constant(job.relativePath)
          )
          .listRowBackground(theme.secondarySystemBackgroundColor)
        }
      } header: {
        if !allowsCellularData {
          HStack {
            Spacer()
            Image(systemName: "wifi")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 20, height: 20)
              .foregroundStyle(theme.linkColor)
              .padding([.trailing], 5)
            Text("upload_wifi_required_title".localized)
              .font(Font(Fonts.body))
              .foregroundStyle(theme.secondaryColor)
            Spacer()
          }
        }
      }
    }
    .navigationTitle("tasks_title")
    .navigationBarTitleDisplayMode(.inline)
    .alert("", isPresented: $showInfoAlert) {
      Button("ok_button", role: .cancel) {}
        .foregroundStyle(theme.linkColor)
    } message: {
      Text("sync_tasks_alert_description")
    }
    .onReceive(syncService.observeTasksCount()) { _ in
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
      queuedJobs = await syncService.getAllQueuedJobs()
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
    }
  }
}
