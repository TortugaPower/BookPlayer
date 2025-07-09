//
//  ItemDetailsForm.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/12/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import PhotosUI
import SwiftUI

struct ItemDetailsForm: View {
  /// View model for the form
  @ObservedObject var viewModel: Model
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
      Section(
        header: Text("section_item_title".localized)
          .foregroundColor(themeViewModel.secondaryColor)
      ) {
        ClearableTextField(viewModel.titlePlaceholder, text: $viewModel.title)
      }
      .listRowBackground(themeViewModel.secondarySystemBackgroundColor)

      if viewModel.showAuthor {
        Section(
          header: Text("section_item_author".localized)
            .foregroundColor(themeViewModel.secondaryColor)
        ) {
          ClearableTextField(viewModel.authorPlaceholder, text: $viewModel.author)
        }
        .listRowBackground(themeViewModel.secondarySystemBackgroundColor)
      }

      ItemDetailsArtworkSectionView(image: $viewModel.selectedImage) {
        showingArtworkOptions = true
      }
      .listRowBackground(themeViewModel.secondarySystemBackgroundColor)
      .actionSheet(isPresented: $showingArtworkOptions) {
        ActionSheet(
          title: Text("artwork_options_title".localized),
          buttons: [
            .default(Text("artwork_photolibrary_title".localized)) {
              showingImagePicker = true
            },
            .default(Text("artwork_clipboard_title".localized)) {
              if let image = UIPasteboard.general.image {
                viewModel.selectedImage = image
              } else {
                showingEmptyPasteboardAlert = true
              }
            },
            .cancel(),
          ]
        )
      }

      if let viewModel = viewModel.hardcoverSectionViewModel {
        ItemDetailsHardcoverSectionView(viewModel: viewModel)
      }
      
      Section {
        EmptyView()
      } footer: {
        VStack(alignment: .leading) {
          Text(viewModel.originalFileName)
          Text("\(Int(viewModel.progress * 100))% " + "progress_title".localized.lowercased())
          if let lastPlayedDate = viewModel.lastPlayedDate {
            Text("watchapp_last_played_title".localized)
              + Text(": " + lastPlayedDate)
          }
        }
        .font(Font(Fonts.body))
        .foregroundColor(themeViewModel.secondaryColor)
      }
    }
    .onChange(
      of: viewModel.selectedImage,
      perform: { _ in
        viewModel.artworkIsUpdated = true
      }
    )
    .sheet(isPresented: $showingImagePicker) {
      ImagePicker(image: $viewModel.selectedImage)
    }
    .alert(isPresented: $showingEmptyPasteboardAlert) {
      Alert(
        title: Text("artwork_clipboard_empty_title".localized),
        dismissButton: .default(Text("ok_button".localized))
      )
    }
    .environmentObject(themeViewModel)
  }
}

extension ItemDetailsForm {
  class Model: ObservableObject {
    /// File name
    @Published var originalFileName: String
    /// Title of the item
    @Published var title: String
    /// Author of the item (only applies for books)
    @Published var author: String
    /// Artwork image
    @Published var selectedImage: UIImage?
    /// Progress of the current item
    let progress: Double
    /// Last played date
    let lastPlayedDate: String?
    /// Original item title
    var titlePlaceholder: String
    /// Original item author
    var authorPlaceholder: String
    /// Determines if there's an update for the artwork
    var artworkIsUpdated: Bool = false
    /// Flag to show the author field
    let showAuthor: Bool

    @Published var hardcoverSectionViewModel: ItemDetailsHardcoverSectionView.Model?

    init(
      originalFileName: String,
      title: String,
      author: String,
      selectedImage: UIImage?,
      progress: Double,
      lastPlayedDate: String?,
      titlePlaceholder: String,
      authorPlaceholder: String,
      showAuthor: Bool,
      hardcoverSectionViewModel: ItemDetailsHardcoverSectionView.Model? = nil
    ) {
      self.originalFileName = originalFileName
      self.title = title
      self.author = author
      self.selectedImage = selectedImage
      self.progress = progress
      self.lastPlayedDate = lastPlayedDate
      self.titlePlaceholder = titlePlaceholder
      self.authorPlaceholder = authorPlaceholder
      self.showAuthor = showAuthor
      self.hardcoverSectionViewModel = hardcoverSectionViewModel
    }
  }
}

#Preview("default") {
  ItemDetailsForm(
    viewModel: ItemDetailsForm.Model(
      originalFileName: "this is a test filename.mp3",
      title: "title",
      author: "author",
      selectedImage: nil,
      progress: 0.01,
      lastPlayedDate: nil,
      titlePlaceholder: "",
      authorPlaceholder: "",
      showAuthor: true
    )
  )
}
