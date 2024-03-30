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

/// Note: This provider does not take into account items at the DB level, only at the disk level
/// so for folders where all the items are offloaded, it won't find items to parse an artwork
public struct AVAudioAssetImageDataProvider: ImageDataProvider {

  public enum ProviderError: Error {
    case missingImage, missingFile, metadataFailed
  }

  private let fileURL: URL
  private let remoteURL: URL?
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
        return handler(.failure(ProviderError.missingFile))
      }
    }
  }

  private func handleFileItem(
    at url: URL,
    handler: @escaping (Result<Data, Error>) -> Void
  ) {
    Task {
      do {
        let data = try await extractDataFrom(url: url)

        handler(.success(data))
      } catch {
        handler(.failure(error))
      }
    }
  }

  private func extractDataFrom(url: URL) async throws -> Data {
    let asset = AVAsset(url: url)

    await asset.loadValues(forKeys: ["metadata"])

    switch asset.statusOfValue(forKey: "metadata", error: nil) {
    case .loaded:
      var imageData: Data?

      if url.pathExtension == "mp3" {
        imageData = self.getDataFromMP3(asset: asset)
      } else if let data = AVMetadataItem.metadataItems(
        from: asset.commonMetadata,
        filteredByIdentifier: .commonIdentifierArtwork
      ).first?.dataValue {
        imageData = data
      }

      if let imageData {
        return imageData
      }

      throw ProviderError.missingImage
    default:
      throw ProviderError.metadataFailed
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
    /// Process any image file from within the folder
    if let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil),
       let imageURL = contents.first(where: { file in
         let type = UTType(filenameExtension: file.pathExtension)
         return type?.isSubtype(of: .image) == true
       }),
       let imageData = try? Data(contentsOf: imageURL) {
      handler(.success(imageData))
    } else { /// Go through the internal files' metadata
      Task {
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

        do {
          let data = try await processNextFolderItem(from: files)

          handler(.success(data))
        } catch {
          handler(.failure(error))
        }
      }
    }
  }

  private func processNextFolderItem(from urls: [URL]) async throws -> Data {
    if urls.isEmpty {
      throw ProviderError.missingImage
    }

    var mutableUrls = urls
    let newURL = mutableUrls.removeFirst()

    guard !newURL.isDirectoryFolder else {
      return try await processNextFolderItem(from: mutableUrls)
    }

    do {
      return try await extractDataFrom(url: newURL)
    } catch {
      return try await processNextFolderItem(from: mutableUrls)
    }
  }
}
