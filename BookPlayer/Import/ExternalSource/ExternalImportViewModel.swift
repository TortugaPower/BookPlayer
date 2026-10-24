//
//  ExternalImportViewModel.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 17/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//
import Combine
import Foundation
import SwiftUI
import BookPlayerKit

@MainActor
final class ExternalImportViewModel: ObservableObject {
  /// OWNED value state, seeded from the producer's staged batch: removals republish
  /// natively. (The previous shape was a computed passthrough onto a shared
  /// ImportManager mailbox — mutations never fired this VM's objectWillChange, so the
  /// delete button was visually dead.)
  @Published private(set) var resources: [SimpleExternalResource]
  private let onConfirm: ([SimpleExternalResource]) -> Void

  init(
    batch: ExternalImportBatch,
    onConfirm: @escaping ([SimpleExternalResource]) -> Void
  ) {
    self.resources = batch.resources
    self.onConfirm = onConfirm
  }

  /// The confirmation-shell rows for the current batch. Pure mapping, kept on the
  /// VM (not in the view body) so the identity/filename/fallback rules are testable.
  var confirmationRows: [ImportConfirmationRow] {
    resources.map { resource in
      ImportConfirmationRow(
        id: resource.providerId,
        icon: "waveform",
        title: resource.libraryItem?.originalFileName ?? "voiceover_unknown_title".localized
      )
    }
  }

  func removeResource(withId id: String) {
    resources.removeAll { $0.providerId == id }
  }

  /// Hands the (possibly edited) selection back to the producing screen's VM,
  /// which sends it on the import bus and owns any post-confirm navigation.
  func confirm() {
    onConfirm(resources)
  }
}
