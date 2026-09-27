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
  /// Set while the task is parked: the row shows why, with Retry and Report
  var pause: TaskPause? = nil
  var onRetry: () -> Void = {}
  var onReport: () -> Void = {}

  @EnvironmentObject var themeViewModel: ThemeViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.S2) {
      HStack {
        Image(systemName: pause == nil ? imageName : "exclamationmark.triangle.fill")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 20, height: 20)
          .foregroundStyle(pause == nil ? themeViewModel.secondaryColor : .red)
          .padding([.trailing], 5)
          .accessibilityHidden(true)
        Text(title)
          .bpFont(.body)
          .foregroundStyle(themeViewModel.primaryColor)
          .frame(maxWidth: .infinity, alignment: .leading)
        if pause == nil {
          CircularProgressView(
            progress: progress,
            isHighlighted: true
          )
        }
      }

      if let pause {
        pausedDetails(pause)
      }
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

extension QueuedSyncTaskRowView {
  @ViewBuilder
  private func pausedDetails(_ pause: TaskPause) -> some View {
    Text(pause.message)
      .bpFont(.caption)
      .foregroundStyle(.red)
      .accessibilityLabel(String(format: "sync_task_paused_voiceover".localized, pause.message))

    HStack(spacing: Spacing.S) {
      pausedAction("sync_task_retry_button", action: onRetry)
      pausedAction("sync_task_report_button", action: onReport)
    }
    .bpFont(.subheadline)
    .foregroundStyle(themeViewModel.linkColor)
  }
}

extension QueuedSyncTaskRowView {
  /// Borderless: plain buttons inside a List row would make the whole row one tap target.
  /// The label is framed to the 44×44 pt minimum, and the hint names the item for VoiceOver
  /// when several rows are parked.
  private func pausedAction(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(titleKey)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .accessibilityHint(title)
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
