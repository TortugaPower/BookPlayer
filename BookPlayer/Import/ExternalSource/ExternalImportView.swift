//
//  ExternalImportView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 17/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//
import SwiftUI
import BookPlayerKit

struct ExternalImportView<Model: ExternalViewModelProtocol>: View {
  @ObservedObject var viewModel: Model
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject private var theme: ThemeViewModel
  
  var body: some View {
    ZStack {
      theme.systemBackgroundColor
        .ignoresSafeArea()
      
      VStack(alignment: .leading, spacing: 20) {
        
        HStack {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.white)
              .frame(width: 44, height: 44)
              .background(
                Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
              )
          }
          
          Spacer()
          
          Button {
            Task {
              dismiss()
              await viewModel.handleImportResources()
            }
          } label: {
            Image(systemName: "checkmark")
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.white)
              .frame(width: 44, height: 44)
              .background(
                Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
              )
          }
        }
        .padding(.top, 10)
        
        // Headers
        Text("Import")
          .font(.system(size: 34, weight: .bold))
          .foregroundColor(.white)
        
        Text("import_warning_description".localized)
          .font(.subheadline)
          .foregroundColor(Color.white.opacity(0.6))
          .lineSpacing(4)
        
        Text("\(viewModel.resources.count) File\(viewModel.resources.count == 1 ? "" : "s")")
          .font(.headline)
          .foregroundColor(Color.white.opacity(0.6))
          .padding(.top, 10)
        
        ScrollView {
          VStack(spacing: 0) {
            ForEach(viewModel.resources) { resource in
              HStack(spacing: 16) {
                Button {
                  withAnimation {
                    viewModel.removeResource(withId: resource.providerId)
                  }
                } label: {
                  Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 20))
                }
                
                // Waveform Icon
                Image(systemName: "waveform")
                  .foregroundColor(.pink)
                
                // File Name
                Text(resource.libraryItem?.title ?? "Unknown Item")
                  .foregroundColor(.white)
                  .font(.system(size: 14))
                  .lineLimit(1)
                
                Spacer()
              }
              .padding(.vertical, 14)
              
              // Separator
              Divider()
                .background(Color.white.opacity(0.2))
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
      viewModel: ExternalImportViewModel(
        importManager: ImportManager(
          libraryService: LibraryService()
        )
      )
    )
  }
}
