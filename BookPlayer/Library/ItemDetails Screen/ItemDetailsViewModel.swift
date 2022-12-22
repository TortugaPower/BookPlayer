//
//  ItemDetailsViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 5/12/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import BookPlayerKit
import Combine

class ItemDetailsViewModel: BaseViewModel<ItemDetailsCoordinator> {
  /// Possible routes for the screen
  enum Routes {
    case cancel
    case done
  }

  /// Item being modified
  let item: SimpleLibraryItem
  /// Library service used for modifications
  let libraryService: LibraryServiceProtocol
  /// View model for the SwiftUI form
  let formViewModel: ItemDetailsFormViewModel
  /// Callback to handle actions on this screen
  public var onTransition: Transition<Routes>?

  private var disposeBag = Set<AnyCancellable>()

  /// Initializer
  init(
    item: SimpleLibraryItem,
    libraryService: LibraryServiceProtocol
  ) {
    self.item = item
    self.libraryService = libraryService
    self.formViewModel = ItemDetailsFormViewModel(item: item)
  }

  func handleCancelAction() {
    onTransition?(.cancel)
  }

  func handleSaveAction() {
    if item.title != formViewModel.title {
      try? libraryService.renameItem(at: item.relativePath, with: formViewModel.title)
    }

    if formViewModel.showAuthor,
       item.details != formViewModel.author {
      libraryService.updateDetails(at: item.relativePath, details: formViewModel.author)
    }

    if formViewModel.artworkIsUpdated {
      ArtworkService.removeCache(for: item.relativePath)
    }

    // TODO: schedule job to update metadata on server

    if formViewModel.artworkIsUpdated,
       let imageData = formViewModel.selectedImage?.jpegData(compressionQuality: 0.3) {
      ArtworkService.storeInCache(imageData, for: item.relativePath) { [weak self] in
        DispatchQueue.main.async {
          self?.onTransition?(.done)
        }
      }
    } else {
      onTransition?(.done)
    }
  }
}
