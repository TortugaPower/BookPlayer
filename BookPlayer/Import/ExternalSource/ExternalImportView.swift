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
      rows: viewModel.confirmationRows,
      /// No description: `import_warning_description` warns that files are still
      /// transferring and the count may change, and neither is true here — the batch is
      /// frozen when the sheet opens and nothing is being copied.
      onRemove: { viewModel.removeResource(withId: $0) },
      onConfirm: {
        viewModel.confirm()
        dismiss()
      },
      onCancel: {
        // Cancelling is just dismissing: `.sheet(item:)` nils the staged batch on its way
        // out. The shell disables interactive dismissal, so this runs only from the X.
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
