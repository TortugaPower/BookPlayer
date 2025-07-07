//
//  AudioMetadataService.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 7/3/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import AVFoundation

public struct AudioMetadata {
  public let title: String
  public let artist: String
  public let artwork: Data?
  
  public init(
    title: String,
    artist: String = "",
    artwork: Data? = nil
  ) {
    self.title = title
    self.artist = artist
    self.artwork = artwork
  }
}

public protocol AudioMetadataServiceProtocol {
  /// Extract metadata from an audio file
  /// - Parameter fileURL: URL to the audio file
  /// - Returns: AudioMetadata if extraction succeeds, nil otherwise
  func extractMetadata(from fileURL: URL) async -> AudioMetadata?
}

public class AudioMetadataService: BPLogger, AudioMetadataServiceProtocol {
  
  public init() {}
  
  public func extractMetadata(from fileURL: URL) async -> AudioMetadata? {
    do {
      let asset = AVAsset(url: fileURL)
      let metadata = try await asset.load(.metadata)

      let title = await extractTitle(from: metadata) ?? fileURL.deletingPathExtension().lastPathComponent
      let artist = await extractArtist(from: metadata)
      let artwork = await extractArtwork(from: metadata)

      return AudioMetadata(
        title: title,
        artist: artist,
        artwork: artwork
      )

    } catch {
      Self.logger.error("Failed to extract metadata from audio file \(fileURL.lastPathComponent): \(error)")
      return nil
    }
  }
  
  private func extractTitle(from metadata: [AVMetadataItem]) async -> String? {
    let titleKeys: [AVMetadataKey] = [
      .commonKeyAlbumName,
      .id3MetadataKeyAlbumTitle,
      .iTunesMetadataKeyAlbum,
      .commonKeyTitle,
      .id3MetadataKeyOriginalAlbumTitle,
    ]
    
    var title: String?

    for key in titleKeys {
      if let metadataItem = metadata.first(where: { $0.commonKey == key }),
         let titleValue = try? await metadataItem.load(.stringValue),
         !titleValue.isEmpty {
        title = titleValue
        break
      }
    }
    
    return title
  }
  
  private func extractArtist(from metadata: [AVMetadataItem]) async -> String {
    let artistKeys: [AVMetadataKey] = [
      .commonKeyAuthor,
      .commonKeyArtist,
      .metadata3GPUserDataKeyAuthor,
      .iTunesMetadataKeyArtist,
      .iTunesMetadataKeyAlbumArtist,
      .id3MetadataKeyOriginalArtist
    ]
    
    for key in artistKeys {
      if let metadataItem = metadata.first(where: { $0.commonKey == key }),
         let artistValue = try? await metadataItem.load(.stringValue),
         !artistValue.isEmpty {
        return artistValue
      }
    }
    
    return ""
  }
  
  private func extractArtwork(from metadata: [AVMetadataItem]) async -> Data? {
    guard let artworkItem = metadata.first(where: { $0.commonKey == .commonKeyArtwork }) else {
      return nil
    }
    
    return try? await artworkItem.load(.dataValue)
  }
}
