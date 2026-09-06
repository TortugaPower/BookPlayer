//
//  ExternalImportView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 17/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//
import SwiftUI
import BookPlayerKit

/// The external (media-server) flow's confirmation sheet: owns the batch-seeded VM
/// and maps it onto the shared `ImportConfirmationView` shell — one flow's use of
/// that shell, not the shell itself.
struct ExternalImportView: View {
  /// Owns the confirmation VM (initModel/@StateObject pattern): the VM is seeded
  /// with the batch VALUE and survives re-renders of the presenting view.
  @StateObject var viewModel: ExternalImportViewModel

  init(initModel: @escaping () -> ExternalImportViewModel) {
    self._viewModel = .init(wrappedValue: initModel())
  }
  @Environment(\.dismiss) var dismiss

  var body: some View {
    ImportConfirmationView(
      rows: viewModel.resources.map { resource in
        ImportConfirmationRow(
          id: resource.providerId,
          icon: "waveform",
          title: resource.libraryItem?.originalFileName ?? "voiceover_unknown_title".localized
        )
      },
      onRemove: { viewModel.removeResource(withId: $0) },
      onConfirm: {
        viewModel.confirm()
        dismiss()
      },
      onCancel: {
        // Dismissal alone is cancellation: .sheet(item:) nils the staged batch
        dismiss()
      }
    )
  }
}

struct ExternalImportView_Previews: PreviewProvider {
  static var previews: some View {
    ExternalImportView(
      initModel: {
        ExternalImportViewModel(
          batch: ExternalImportBatch(resources: []),
          onConfirm: { _ in }
        )
      }
    )
    .environmentObject(ThemeViewModel())
  }
}
