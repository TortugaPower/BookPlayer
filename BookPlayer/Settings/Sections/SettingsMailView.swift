//
//  SettingsMailView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 20/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import MessageUI
import SwiftUI

struct AttachmentData {
  let data: Data
  let mimeType: String
  let fileName: String
}

struct SettingsMailView: UIViewControllerRepresentable {
  @Environment(\.dismiss) var dismiss

  let recipients: [String]
  let subject: String
  let messageBody: String
  let isHTML: Bool
  let attachmentData: AttachmentData?

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeUIViewController(context: Context) -> MFMailComposeViewController {
    let vc = MFMailComposeViewController()
    vc.setToRecipients(recipients)
    vc.setSubject(subject)
    vc.setMessageBody(messageBody, isHTML: isHTML)
    vc.mailComposeDelegate = context.coordinator
    if let attachmentData {
      vc.addAttachmentData(
        attachmentData.data,
        mimeType: attachmentData.mimeType,
        fileName: attachmentData.fileName
      )
    }
    return vc
  }

  func updateUIViewController(
    _ uiViewController: MFMailComposeViewController,
    context: Context
  ) {}

  class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
    let parent: SettingsMailView

    init(_ parent: SettingsMailView) {
      self.parent = parent
    }

    func mailComposeController(
      _ controller: MFMailComposeViewController,
      didFinishWith result: MFMailComposeResult,
      error: Error?
    ) {
      parent.dismiss()
    }
  }
}

