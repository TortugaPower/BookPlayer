//
//  ActivitySharingView.swift
//  BookPlayer
//
//  Created by dawsonamf on 6/28/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import GroupActivities
import SwiftUI
import UIKit

struct ActivitySharingView: UIViewControllerRepresentable, BPLogger {
  let activity: AudioBookActivity

  func makeUIViewController(context: Context) -> UIViewController {
    do {
      return try GroupActivitySharingController(activity)
    } catch {
      Self.logger.error("Failed to create GroupActivitySharingController: \(error)")
      return UIHostingController(
        rootView: Text("shareplay_unavailable_description".localized)
          .multilineTextAlignment(.center)
          .padding()
      )
    }
  }

  func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
