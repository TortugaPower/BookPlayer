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

class ItemDetailsFormViewModel: ObservableObject {
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
    self.progress = item.progress
    self.originalFileName = item.originalFileName
    self.showAuthor = item.type == .book
    self.originalImageDataProvider = ArtworkService.getArtworkProvider(for: item.relativePath)
    let cachedImageURL = ArtworkService.getCachedImageURL(for: item.relativePath)
    self.selectedImage = UIImage(contentsOfFile: cachedImageURL.path)
  }
}
