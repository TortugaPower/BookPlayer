//
//  AVAudioAssetImageDataProvider.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/23/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import AVFoundation
import Foundation
import Kingfisher

public struct AVAudioAssetImageDataProvider: ImageDataProvider {

  public enum AVAudioAssetImageDataProviderError: Error {
    case missingImage, missingFile
  }

  public let fileURL: URL
  public var cacheKey: String

  public init(fileURL: URL, cacheKey: String) {
    self.fileURL = fileURL
    self.cacheKey = cacheKey
  }

  public func data(handler: @escaping (Result<Data, Error>) -> Void) {
    DispatchQueue.global().async {
      var isDirectory: ObjCBool = false

      guard FileManager.default.fileExists(atPath: self.fileURL.path, isDirectory: &isDirectory) else {
        return handler(.failure(AVAudioAssetImageDataProviderError.missingFile))
      }

      if isDirectory.boolValue {
        self.handleDirectory(at: self.fileURL, handler: handler)
      } else {
        self.handleFileItem(at: self.fileURL, handler: handler)
      }
    }
  }

  private func handleFileItem(at url: URL, handler: @escaping (Result<Data, Error>) -> Void) {
    self.extractDataFrom(url: url) { data in
      guard let data = data else {
        return handler(.failure(AVAudioAssetImageDataProviderError.missingImage))
      }

      handler(.success(data))
    }
  }

  private func extractDataFrom(url: URL, callback: @escaping (Data?) -> Void) {
    let asset = AVAsset(url: url)

    asset.loadValuesAsynchronously(forKeys: ["commonMetadata", "metadata"]) {
      var imageData: Data?

      if fileURL.pathExtension == "mp3" {
        imageData = self.getDataFromMP3(asset: asset)
      } else if let data = AVMetadataItem.metadataItems(
        from: asset.commonMetadata,
        filteredByIdentifier: .commonIdentifierArtwork
      ).first?.dataValue {
        imageData = data
      }

      guard let imageData = imageData else {
        return callback(nil)
      }

      callback(imageData)
    }
  }

  private func getDataFromMP3(asset: AVAsset) -> Data? {
    for item in asset.metadata {
      guard let key = item.commonKey?.rawValue,
            key == "artwork",
            let value = item.value as? Data else { continue }

      return value
    }

    return nil
  }

  // Folders

  private func handleDirectory(at url: URL, handler: @escaping (Result<Data, Error>) -> Void) {
    let enumerator = FileManager.default.enumerator(
      at: self.fileURL,
      includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
      options: [.skipsHiddenFiles], errorHandler: { (url, error) -> Bool in
        print("directoryEnumerator error at \(url): ", error)
        return true
      })!


    self.processNextFolderItem(from: enumerator) { url in
      guard let url = url else {
        return handler(.failure(AVAudioAssetImageDataProviderError.missingImage))
      }

      self.handleFileItem(at: url, handler: handler)
    }
  }


  private func processNextFolderItem(from enumerator: FileManager.DirectoryEnumerator,
                           callback: @escaping (URL?) -> Void) {
    let url = enumerator.nextObject()

    if url == nil {
      return callback(nil)
    }

    guard let newURL = url as? URL,
            !newURL.isDirectoryFolder else {
      return self.processNextFolderItem(from: enumerator, callback: callback)
    }

    self.extractDataFrom(url: newURL) { data in
      // If item doesn't have an artwork, try with the next one
      if data == nil {
        return self.processNextFolderItem(from: enumerator, callback: callback)
      }

      callback(newURL)
    }
  }
}
