//
//  ItemDetailsFormViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 20/12/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
import UIKit

class ItemDetailsFormViewModel: ObservableObject {
  /// Title of the item
  @Published var title: String
  /// Author of the item (only applies for books)
  @Published var author: String
  /// Artwork image
  @Published var selectedImage: UIImage?
  /// Original item title
  var titlePlaceholder: String
  /// Original item author
  var authorPlaceholder: String
  /// Determines if there's an update for the artwork
  var artworkIsUpdated: Bool = false
  /// Flag to show the author field
  let showAuthor: Bool
  /// Image data provider to load original artwork from file
  let originalImageDataProvider: AVAudioAssetImageDataProvider

  /// Initializer
  init(item: SimpleLibraryItem) {
    self.title = item.title
    self.titlePlaceholder = item.title
    self.author = item.details
    self.authorPlaceholder = item.details
    self.showAuthor = item.type == .book
    self.originalImageDataProvider = ArtworkService.getArtworkProvider(for: item.relativePath)
    let cachedImageURL = ArtworkService.getCachedImageURL(for: item.relativePath)
    self.selectedImage = UIImage(contentsOfFile: cachedImageURL.path)
  }
}
