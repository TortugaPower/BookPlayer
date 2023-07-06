//
//  StorageView.swift
//  BookPlayer
//
//  Created by Dmitrij Hojkolov on 29.06.2023.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import SwiftUI
import BookPlayerKit

struct StorageView: View {
  
  @StateObject var themeViewModel = ThemeViewModel()
  @ObservedObject var viewModel: StorageViewModel
  
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
            
            Text(viewModel.getLibrarySize())
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
          
          if viewModel.hasFilesWithWarning {
            Button("storage_fix_all_title".localized) {
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
      .navigationTitle("settings_storage_title".localized)
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
                Text("sort_by_size_title".localized).tag(StorageViewModel.SortBy.size)
                Text("title_button".localized).tag(StorageViewModel.SortBy.title)
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
  
  static var previews: some View {
    StorageView(viewModel: .demo)
  }
}
