//
//  ExternalImportView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 17/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//
import SwiftUI
import BookPlayerKit

struct ExternalImportView: View {
  /// Owns the confirmation VM (initModel/@StateObject pattern): the VM is seeded
  /// with the batch VALUE and survives re-renders of the presenting view.
  @StateObject var viewModel: ExternalImportViewModel

  init(initModel: @escaping () -> ExternalImportViewModel) {
    self._viewModel = .init(wrappedValue: initModel())
  }
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject private var theme: ThemeViewModel
  
  var body: some View {
    ZStack {
      theme.systemBackgroundColor
        .ignoresSafeArea()
      
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          Button {
            // Dismissal alone is cancellation: .sheet(item:) nils the staged batch
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .accessibilityLabel("cancel_button".localized)
              .bpFont(.title)
              .foregroundColor(theme.primaryColor)
              .frame(width: 44, height: 44)
              .background(
                Circle().stroke(theme.systemBackgroundColor.opacity(0.3), lineWidth: 1)
              )
          }
          
          Spacer()
          
          Button {
            viewModel.confirm()
            dismiss()
          } label: {
            Image(systemName: "checkmark")
              .accessibilityLabel("import_button".localized)
              .bpFont(.title)
              .foregroundColor(theme.primaryColor)
              .frame(width: 44, height: 44)
              .background(
                Circle().stroke(theme.systemBackgroundColor.opacity(0.3), lineWidth: 1)
              )
          }
        }
        .safeAreaPadding(.top)
        
        // Headers
        Text("import_title".localized)
          .bpFont(.titleStory)
          .fontWeight(.bold)
          .foregroundColor(theme.primaryColor)
        
        Text("import_warning_description".localized)
          .bpFont(.subheadline)
          .foregroundColor(theme.primaryColor.opacity(0.6))
          .lineSpacing(4)
        
        Text(String.localizedStringWithFormat("files_title".localized, viewModel.resources.count))
          .bpFont(.headline)
          .foregroundColor(theme.primaryColor.opacity(0.6))
          .padding(.top, 10)
        
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(viewModel.resources, id: \.providerId) { resource in
              HStack(spacing: 16) {
                Button {
                  withAnimation {
                    viewModel.removeResource(withId: resource.providerId)
                  }
                } label: {
                  Image(systemName: "minus.circle.fill")
                    .accessibilityLabel("delete_button".localized)
                    .foregroundColor(.red)
                    .bpFont(.titleLarge)
                }
                
                // Waveform Icon
                Image(systemName: "waveform")
                  .foregroundColor(.pink)
                
                // File Name
                Text(resource.libraryItem?.originalFileName ?? "voiceover_unknown_title".localized)
                  .foregroundColor(theme.primaryColor)
                  .bpFont(.footnote)
                  .lineLimit(1)
                
                Spacer()
              }
              .padding(.vertical, 14)
              
              // Separator
              Divider()
                .background(theme.systemBackgroundColor.opacity(0.2))
            }
          }
        }
        
        Spacer()
      }
      .padding(.horizontal, 24)
    }
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
  }
}
