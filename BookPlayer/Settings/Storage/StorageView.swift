//
//  StorageView.swift
//  BookPlayer
//
//  Created by Dmitrij Hojkolov on 29.06.2023.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct StorageView<Model: StorageViewModelProtocol>: View {

  @EnvironmentObject var theme: ThemeViewModel
  @ObservedObject var viewModel: Model

  var body: some View {
    if viewModel.showProgressIndicator {
      VStack(spacing: 16) {
        if let progress = viewModel.fixProgress {
          VStack(spacing: 8) {
            ProgressView(value: progress.percentage)
              .progressViewStyle(.linear)

            Text("\(progress.processed) of \(progress.total)")
              .bpFont(.subheadline)
              .foregroundStyle(theme.secondaryColor)

            Button("cancel_button".localized) {
              viewModel.cancelFixAll()
            }
            .foregroundStyle(theme.linkColor)
            .padding(.top, 8)
          }
          .padding()
        } else {
          ProgressView()
        }
      }
    } else {
      Form {
        Section {
          HStack(alignment: .center) {
            Text("storage_total_title".localized)
              .foregroundStyle(theme.primaryColor)
            Spacer()
            Text(viewModel.getTotalFoldersSize())
              .foregroundStyle(theme.secondaryColor)
          }
          .accessibilityElement(children: .combine)

          HStack(alignment: .center) {
            Text("storage_artwork_cache_title".localized)
              .foregroundStyle(theme.primaryColor)
            Spacer()
            Text(viewModel.getArtworkFolderSize())
              .foregroundStyle(theme.secondaryColor)
          }
          .accessibilityElement(children: .combine)
        }

        Section {
          List {
            ForEach(viewModel.publishedFiles) { file in
              StorageRowView(
                item: file,
                onDeleteTap: {
                  viewModel.storageAlert = .delete(item: file)
                  viewModel.showAlert = true
                },
                onWarningTap: {
                  viewModel.storageAlert = .fix(item: file)
                  viewModel.showAlert = true
                }
              )
            }
          }
        } header: {
          HStack {
            Text(
              String.localizedStringWithFormat("files_title".localized, viewModel.publishedFiles.count)
                .localizedUppercase
            )
            .bpFont(.subheadline)
            .foregroundStyle(theme.secondaryColor)
            .accessibilityAddTraits(.isHeader)

            Spacer()

            if viewModel.showFixAllButton {
              Button(viewModel.fixButtonTitle) {
                viewModel.storageAlert = .fixAll
                viewModel.showAlert = true
              }
              .foregroundStyle(theme.linkColor)
            }
          }
        }
      }
      .scrollContentBackground(.hidden)
      .background(theme.systemGroupedBackgroundColor)
      .navigationTitle(viewModel.navigationTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Menu {
            Picker(
              selection: $viewModel.sortBy,
              label: Text("sort_button_title".localized)
            ) {
              Text("sort_by_size_title".localized).tag(BPStorageSortBy.size)
              Text("title_button".localized).tag(BPStorageSortBy.title)
            }
          } label: {
            HStack {
              Text("sort_button_title".localized)
              Image(systemName: "chevron.down")
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
            }
            .foregroundStyle(theme.linkColor)
          }
        }
      }
      .alert(isPresented: $viewModel.showAlert) {
        viewModel.alert
      }
    }
  }
}

struct StorageView_Previews: PreviewProvider {
  class MockStorageViewModel: StorageViewModelProtocol, ObservableObject {
    var folderURL: URL { URL(string: "file://")! }
    var navigationTitle: String = "Files"
    var publishedFiles: [StorageItem] = []
    var storageAlert: BPStorageAlert = .none
    var sortBy: BPStorageSortBy = .size
    var showFixAllButton: Bool = true
    var showAlert: Bool = false
    var showProgressIndicator: Bool = false
    var fixProgress: FixProgress? = nil
    var alert: Alert { Alert(title: Text("")) }
    let fixButtonTitle = "Fix all"

    func getTotalFoldersSize() -> String { return "0 Kb" }
    func getArtworkFolderSize() -> String { return "0 Kb" }
    func dismiss() {}
    func cancelFixAll() {}
  }
  static var previews: some View {
    StorageView(viewModel: MockStorageViewModel())
  }
}
