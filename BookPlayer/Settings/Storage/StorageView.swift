//
//  StorageView.swift
//  BookPlayer
//
//  Created by Dmitrij Hojkolov on 29.06.2023.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import SwiftUI
import BookPlayerKit

struct StorageView<Model: StorageViewModelProtocol>: View {
  
  @StateObject var themeViewModel = ThemeViewModel()
  @ObservedObject var viewModel: Model
  
  var body: some View {
    if viewModel.showProgressIndicator {
      ProgressView()
    } else {
      VStack(spacing: 0) {
        
        // Total space
        VStack {
          Divider()
            .background(themeViewModel.separatorColor)
          
          HStack(alignment: .center) {
            Text("storage_total_title".localized)
              .foregroundColor(themeViewModel.primaryColor)
            
            Spacer()
            
            Text(viewModel.getFolderSize())
              .foregroundColor(themeViewModel.secondaryColor)
          }
          .padding(.horizontal, 16)
          .padding(.top, 4)
          .accessibilityElement(children: .combine)
          
          Divider()
            .background(themeViewModel.separatorColor)
        }
        .background(themeViewModel.systemBackgroundColor)
        .padding(.top, 14)
        
        HStack {
          Text(
            String.localizedStringWithFormat("files_title".localized, viewModel.publishedFiles.count)
              .localizedUppercase
          )
          .font(Font(Fonts.subheadline))
          .foregroundColor(themeViewModel.primaryColor)
          .accessibilityAddTraits(.isHeader)
          
          Spacer()
          
          if viewModel.showFixAllButton {
            Button(viewModel.fixButtonTitle) {
              viewModel.storageAlert = .fixAll
              viewModel.showAlert = true
            }
            .foregroundColor(themeViewModel.linkColor)
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 30)
        .padding(.bottom, 8)
        
        Divider()
          .background(themeViewModel.separatorColor)
        
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(viewModel.publishedFiles) { file in
              VStack(spacing: 0) {
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
                .padding(.vertical, 10)
                
                Divider()
                  .padding(.leading, 75)
                  .background(themeViewModel.separatorColor)
              }
              
            }
          }
        }
        .background(themeViewModel.systemBackgroundColor)
      }
      .background(
        themeViewModel.systemGroupedBackgroundColor
          .edgesIgnoringSafeArea(.bottom)
      )
      .environmentObject(themeViewModel)
      .navigationTitle(viewModel.navigationTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(
            action: viewModel.dismiss,
            label: {
              Image(systemName: "xmark")
                .foregroundColor(themeViewModel.linkColor)
            }
          )
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          Menu {
            Picker(
              selection: $viewModel.sortBy,
              label: Text("sort_button_title".localized)) {
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
            .foregroundColor(themeViewModel.linkColor)
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
    var alert: Alert { Alert(title: Text("")) }
    let fixButtonTitle = "Fix all"
    
    func getFolderSize() -> String { return "0 Kb" }
    func dismiss() {}
  }
  static var previews: some View {
    StorageView(viewModel: MockStorageViewModel())
  }
}
