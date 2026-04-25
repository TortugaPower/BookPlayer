//
//  QueuedSyncTaskRowView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 26/5/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct QueuedSyncTaskRowView: View {
  @State var progress: Double = 0.0

  @Binding var imageName: String
  @Binding var title: String
  let progressKey: String
  var initialProgress: Double
  var isUpload: Bool

  @EnvironmentObject var themeViewModel: ThemeViewModel

  var body: some View {
    HStack {
      Image(systemName: imageName)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 20, height: 20)
        .foregroundStyle(themeViewModel.secondaryColor)
        .padding([.trailing], 5)
      Text(title)
        .bpFont(.body)
        .foregroundStyle(themeViewModel.primaryColor)
        .frame(maxWidth: .infinity, alignment: .leading)
      CircularProgressView(
        progress: progress,
        isHighlighted: true
      )
    }
    .padding([.vertical], 3)
    .onAppear {
      self.progress = self.initialProgress
    }
    .onReceive(
      NotificationCenter.default.publisher(for: .uploadProgressUpdated)
        .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
    ) { notification in
      guard
        self.isUpload,
        let uuid = notification.userInfo?["uuid"] as? String,
        let relativePath = notification.userInfo?["relativePath"] as? String,
        let progress = notification.userInfo?["progress"] as? Double,
        SyncProgressKey.resolve(uuid: uuid, relativePath: relativePath) == self.progressKey
      else { return }
      self.progress = progress
    }
  }
}

struct QueuedSyncTaskRowView_Previews: PreviewProvider {
  static var previews: some View {
    QueuedSyncTaskRowView(
      imageName: .constant("bookmark"),
      title: .constant("Task"),
      progressKey: "preview-key",
      initialProgress: 0,
      isUpload: false
    )
    .environmentObject(ThemeViewModel())
  }
}
