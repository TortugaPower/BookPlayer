//
//  ItemDetailsForm.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/12/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import PhotosUI

struct ItemDetailsForm: View {
  /// View model for the form
  @ObservedObject var viewModel: ItemDetailsFormViewModel
  /// Theme view model to update colors
  @StateObject var themeViewModel = ThemeViewModel()
  /// Flag to show action sheet for the artwork
  @State private var showingArtworkOptions = false
  /// Flag to show the ImagePicker
  @State private var showingImagePicker = false
  /// Flag to show the empty pasteboard alert
  @State private var showingEmptyPasteboardAlert = false

  var body: some View {
    Form {
      Section(header: Text("Details")
        .foregroundColor(themeViewModel.secondaryColor)
      ) {
        ClearableTextField("Title", text: $viewModel.title)
        if viewModel.showAuthor {
          ClearableTextField("Author", text: $viewModel.author)
        }
      }
      .listRowBackground(themeViewModel.secondarySystemBackgroundColor)

      ItemDetailsArtworkSectionView(image: $viewModel.selectedImage) {
        showingArtworkOptions = true
      }
      .listRowBackground(themeViewModel.secondarySystemBackgroundColor)
    }
    .onChange(of: viewModel.selectedImage, perform: { _ in
      viewModel.artworkIsUpdated = true
    })
    .actionSheet(isPresented: $showingArtworkOptions) {
      ActionSheet(
        title: Text("Artwork options"),
        buttons: [
          .default(Text("Choose from Photo Library")) {
            showingImagePicker = true
          },
          .default(Text("Paste from clipboard")) {
            if let image = UIPasteboard.general.image {
              viewModel.selectedImage = image
            } else {
              showingEmptyPasteboardAlert = true
            }
          },
          .default(Text("Reset")) {
            viewModel.resetArtwork()
          },
          .cancel(),
        ]
      )
    }
    .sheet(isPresented: $showingImagePicker) {
      ImagePicker(image: $viewModel.selectedImage)
    }
    .alert(isPresented: $showingEmptyPasteboardAlert) {
      Alert(
        title: Text("No image in the clipboard"),
        dismissButton: .default(Text("Ok"))
      )
    }
  }
}

struct ItemDetailsForm_Previews: PreviewProvider {
  static var previews: some View {
    ItemDetailsForm(
      viewModel: ItemDetailsFormViewModel(
        item: SimpleLibraryItem(
          title: "title",
          details: "details",
          duration: 100,
          percentCompleted: 1,
          isFinished: false,
          relativePath: "",
          parentFolder: nil,
          originalFileName: "",
          lastPlayDate: nil,
          type: .book
        )
      )
    )
  }
}
