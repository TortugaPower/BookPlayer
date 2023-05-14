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
  public let remoteURL: URL?
  public var cacheKey: String

  public init(
    fileURL: URL,
    remoteURL: URL? = nil,
    cacheKey: String
  ) {
    self.fileURL = fileURL
    self.remoteURL = remoteURL
    self.cacheKey = cacheKey
  }

  public func data(handler: @escaping (Result<Data, Error>) -> Void) {
    DispatchQueue.global(qos: .background).async {
      var isDirectory: ObjCBool = false

      if FileManager.default.fileExists(atPath: self.fileURL.path, isDirectory: &isDirectory) {
        if isDirectory.boolValue {
          self.handleDirectory(at: self.fileURL, handler: handler)
        } else {
          self.handleFileItem(at: self.fileURL, handler: handler)
        }
      } else if let remoteURL {
        self.handleFileItem(at: remoteURL, handler: handler)
      } else {
        return handler(.failure(AVAudioAssetImageDataProviderError.missingFile))
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

      if url.pathExtension == "mp3" {
        imageData = self.getDataFromMP3(asset: asset)
      } else if let data = AVMetadataItem.metadataItems(
        from: asset.commonMetadata,
        filteredByIdentifier: .commonIdentifierArtwork
      ).first?.dataValue {
        imageData = data
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

    var files = [URL]()
    for case let fileURL as URL in enumerator {
      files.append(fileURL)
    }

    // sort items to same order as library
    files.sort { a, b in
      guard let first = a.getAppOrderRank() else {
        return false
      }

      guard let second = b.getAppOrderRank() else {
        return true
      }

      return first < second
    }

    self.processNextFolderItem(from: files) { url in
      guard let url = url else {
        return handler(.failure(AVAudioAssetImageDataProviderError.missingImage))
      }

      self.handleFileItem(at: url, handler: handler)
    }
  }

  private func processNextFolderItem(from urls: [URL],
                                     callback: @escaping (URL?) -> Void) {
    if urls.isEmpty {
      return callback(nil)
    }

    var mutableUrls = urls
    let newURL = mutableUrls.removeFirst()

    guard !newURL.isDirectoryFolder else {
      return self.processNextFolderItem(from: mutableUrls, callback: callback)
    }

    self.extractDataFrom(url: newURL) { data in
      // If item doesn't have an artwork, try with the next one
      guard let newData = data else {
        return self.processNextFolderItem(from: mutableUrls, callback: callback)
      }

      ArtworkService.storeInCache(newData, for: self.cacheKey)
      callback(newURL)
    }
  }
}
