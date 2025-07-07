//
//  ItemDetailsFormViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 20/12/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
import UIKit

final class ItemDetailsFormViewModel: ItemDetailsForm.Model {
  init(item: SimpleLibraryItem, lastPlayedDate: Date?, hardcoverService: HardcoverServiceProtocol) {
    let cachedImageURL = ArtworkService.getCachedImageURL(for: item.relativePath)

    let playedDate: String?
    if let lastPlayedDate {
      let formatter = DateFormatter()
      formatter.timeStyle = .short
      formatter.dateStyle = .medium
      playedDate = formatter.string(from: lastPlayedDate)
    } else {
      playedDate = nil
    }

    super.init(
      originalFileName: item.originalFileName,
      title: item.title,
      author: item.details,
      selectedImage: UIImage(contentsOfFile: cachedImageURL.path),
      progress: item.progress,
      lastPlayedDate: playedDate,
      titlePlaceholder: item.title,
      authorPlaceholder: item.details,
      showAuthor: item.type == .book
    )

    hardcoverSectionViewModel = ItemDetailsHardcoverSectionViewModel(
      item: item,
      hardcoverService: hardcoverService
    )
  }
}
