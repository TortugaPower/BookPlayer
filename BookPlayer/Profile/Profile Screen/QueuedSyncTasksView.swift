//
//  QueuedSyncTasksView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 26/5/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct QueuedSyncTasksView<Model: QueuedSyncTasksViewModelProtocol>: View {
  @ObservedObject var viewModel: Model
  @StateObject var themeViewModel = ThemeViewModel()

  func parseImageName(_ job: QueuedJobInfo) -> String {
    switch job.jobType {
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
    }
  }

  var body: some View {
    if #available(iOS 16.0, *) {
      List {
        ForEach(viewModel.queuedJobs) { job in
          QueuedSyncTaskRowView(
            imageName: .constant(parseImageName(job)),
            title: .constant(job.relativePath)
          )
          .listRowBackground(themeViewModel.secondarySystemBackgroundColor)
        }
      }
      .scrollContentBackground(.hidden)
    } else {
      List {
        ForEach(viewModel.queuedJobs) { job in
          QueuedSyncTaskRowView(
            imageName: .constant(parseImageName(job)),
            title: .constant(job.relativePath)
          )
        }
      }
    }
  }
}

struct QueuedSyncTasksView_Previews: PreviewProvider {
  class MockQueuedSyncTasksViewModel: QueuedSyncTasksViewModelProtocol, ObservableObject {
    var queuedJobs: [BookPlayerKit.QueuedJobInfo] = []
  }

  static var previews: some View {
    QueuedSyncTasksView(viewModel: MockQueuedSyncTasksViewModel())
  }
}
