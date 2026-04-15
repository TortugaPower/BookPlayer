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

struct QueuedTasksView: View {
  @Environment(\.accountService) private var accountService
  @EnvironmentObject private var theme: ThemeViewModel
  
  var body: some View {
    VStack(spacing: 0) {
      if accountService.account.hasSubscription,
        !accountService.account.id.isEmpty
      {
        NavigationLink(value: ProfileScreen.tasks) {
          SyncTasksCardView()
        }
        .padding(.bottom, Spacing.S1)
      }
        
      NavigationLink(value: ProfileScreen.concurrentTasks) {
        ConcurrentTasksCardView()
      }
      
      Spacer()
    }
    .background(theme.systemBackgroundColor)
    .toolbarColorScheme(theme.useDarkVariant ? .dark : .light, for: .navigationBar)
    .navigationTitle("Queued Tasks")
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
