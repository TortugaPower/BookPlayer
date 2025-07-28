//
//  QueuedSyncTasksView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 26/5/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct QueuedSyncTasksView<Model: QueuedSyncTasksViewModelProtocol>: View {
  @ObservedObject var viewModel: Model
  @StateObject var themeViewModel = ThemeViewModel()

  var listView: some View {
    return List {
      Section {
        ForEach(viewModel.queuedJobs) { job in
          QueuedSyncTaskRowView(
            imageName: .constant(parseImageName(job.jobType)),
            title: .constant(job.relativePath)
          )
          .listRowBackground(themeViewModel.secondarySystemBackgroundColor)
        }
      } header: {
        if !viewModel.allowsCellularData {
          HStack {
            Spacer()
            Image(systemName: "wifi")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 20, height: 20)
              .foregroundStyle(themeViewModel.linkColor)
              .padding([.trailing], 5)
            Text("upload_wifi_required_title".localized)
              .font(Font(Fonts.body))
              .foregroundStyle(themeViewModel.secondaryColor)
            Spacer()
          }
        }
      }
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

  var body: some View {
    listView
      .defaultFormBackground()
      .environmentObject(themeViewModel)
  }
}

struct QueuedSyncTasksView_Previews: PreviewProvider {
  class MockQueuedSyncTasksViewModel: QueuedSyncTasksViewModelProtocol, ObservableObject {
    var allowsCellularData: Bool = false
    var queuedJobs: [BookPlayerKit.SyncTaskReference] = [
      SyncTaskReference(
        id: "1",
        relativePath: "test/path.mp3",
        jobType: .upload
      ),
      SyncTaskReference(
        id: "2",
        relativePath: "test/path2.mp3",
        jobType: .upload
      )
    ]
  }

  static var previews: some View {
    QueuedSyncTasksView(viewModel: MockQueuedSyncTasksViewModel())
  }
}
