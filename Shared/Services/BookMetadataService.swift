//
//  BookMetadataService.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 7/3/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import CoreMedia

public struct ChapterMetadata {
  public let title: String
  public let start: TimeInterval
  public let duration: TimeInterval
  public let index: Int
  
  public init(
    title: String,
    start: TimeInterval,
    duration: TimeInterval,
    index: Int
  ) {
    self.title = title
    self.start = start
    self.duration = duration
    self.index = index
  }
}

public struct AudioMetadata {
  public let title: String
  public let artist: String
  public let duration: TimeInterval
  public let artwork: Data?
  public let chapters: [ChapterMetadata]?
  
  public init(
    title: String,
    artist: String = "",
    duration: TimeInterval = 0,
    artwork: Data? = nil,
    chapters: [ChapterMetadata]? = nil
  ) {
    self.title = title
    self.artist = artist
    self.duration = duration
    self.artwork = artwork
    self.chapters = chapters
  }
}

public protocol BookMetadataServiceProtocol {
  /// Extract metadata from an audio file
  /// - Parameter fileURL: URL to the audio file
  /// - Returns: AudioMetadata if extraction succeeds, nil otherwise
  func extractMetadata(from fileURL: URL) async -> AudioMetadata?
  
  /// Extract metadata from an AVAsset
  /// - Parameter asset: The AVAsset to extract metadata from
  /// - Returns: AudioMetadata if extraction succeeds, nil otherwise
  func extractMetadata(from asset: AVAsset) async -> AudioMetadata?
}

public class BookMetadataService: BPLogger, BookMetadataServiceProtocol {
  
  public init() {}
  
  public func extractMetadata(from fileURL: URL) async -> AudioMetadata? {
    let asset = AVURLAsset(url: fileURL)
    return await extractMetadata(from: asset)
  }
  
  public func extractMetadata(from asset: AVAsset) async -> AudioMetadata? {
    do {
      let metadata = try await asset.load(.metadata)
      let duration = try await asset.load(.duration)
      let durationSeconds = CMTimeGetSeconds(duration)

      let title = await extractTitle(from: metadata)
      let artist = await extractArtist(from: metadata)
      let artwork = await extractArtwork(from: metadata)
      let chapters = await extractChapters(from: asset, duration: durationSeconds)

      return AudioMetadata(
        title: title,
        artist: artist,
        duration: durationSeconds,
        artwork: artwork,
        chapters: chapters
      )

    } catch {
      Self.logger.error("Failed to extract metadata from audio asset: \(error)")
      return nil
    }
  }
  
  private func extractTitle(from metadata: [AVMetadataItem]) async -> String {
    let titleKeys: [AVMetadataKey] = [
      .commonKeyTitle,              // Actual title - should be first
      .commonKeyAlbumName,          // Album name (fallback for audiobooks)
      .id3MetadataKeyAlbumTitle,
      .iTunesMetadataKeyAlbum,
      .id3MetadataKeyOriginalAlbumTitle,
    ]
    
    for key in titleKeys {
      if let metadataItem = metadata.first(where: { $0.commonKey == key }),
         let titleValue = try? await metadataItem.load(.stringValue),
         !titleValue.isEmpty {
        return titleValue
      }
    }
    
    return ""
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
  
  // MARK: - Chapter Extraction
  
  private func extractChapters(from asset: AVAsset, duration: TimeInterval) async -> [ChapterMetadata]? {
    do {
      let metadata = try await asset.load(.metadata)
      let availableChapterLocales = try await asset.load(.availableChapterLocales)
      
      // First try: Native chapter support (works for M4B, some M4A, properly tagged files)
      if !availableChapterLocales.isEmpty {
        return await extractStandardChapters(from: asset, locales: availableChapterLocales)
      }
      
      // Second try: Check what metadata identifiers exist
      let identifiers = metadata.compactMap { $0.identifier?.rawValue }
      
      // FLAC/Vorbis chapters (CHAPTER tags)
      if identifiers.contains(where: { $0.contains("CHAPTER") && !$0.contains("NAME") }) {
        return await extractVorbisChapters(from: metadata, duration: duration)
      }

      // MP3 Overdrive chapters (ID3 TXXX tag)
      if identifiers.contains("id3/TXXX") {
        return await extractOverdriveChapters(from: metadata, duration: duration)
      }

      // MP3 standard chapters (ID3v2.3+ CHAP frames)
      // Note: Currently AVFoundation doesn't fully expose CHAP frame data,
      // but this may be supported in future iOS releases.
      if identifiers.contains(where: { $0.hasPrefix("id3/CHAP") }) {
        return await extractID3Chapters(from: metadata, duration: duration)
      }

      return nil
    } catch {
      Self.logger.error("Failed to extract chapters: \(error)")
      return nil
    }
  }
  
  private func extractStandardChapters(from asset: AVAsset, locales: [Locale]) async -> [ChapterMetadata]? {
    var allChapters: [ChapterMetadata] = []

    for locale in locales {
      do {
        let chaptersMetadata = try await asset.loadChapterMetadataGroups(
          withTitleLocale: locale,
          containingItemsWithCommonKeys: [AVMetadataKey.commonKeyArtwork]
        )

        for (index, chapterMetadata) in chaptersMetadata.enumerated() {
          let chapterIndex = index + 1

          // Get title using async load API
          let titleItem = AVMetadataItem.metadataItems(
            from: chapterMetadata.items,
            withKey: AVMetadataKey.commonKeyTitle,
            keySpace: AVMetadataKeySpace.common
          ).first
          let title = (try? await titleItem?.load(.stringValue)) ?? ""

          let start = CMTimeGetSeconds(chapterMetadata.timeRange.start)
          let duration = CMTimeGetSeconds(chapterMetadata.timeRange.duration)

          let chapter = ChapterMetadata(
            title: title,
            start: start,
            duration: duration,
            index: chapterIndex
          )

          allChapters.append(chapter)
        }
      } catch {
        Self.logger.error("Failed to load chapter metadata for locale \(locale): \(error)")
      }
    }

    return allChapters.isEmpty ? nil : allChapters
  }
  
  private func extractVorbisChapters(from metadata: [AVMetadataItem], duration: TimeInterval) async -> [ChapterMetadata]? {
    var chapterMap: [Int: (time: String?, name: String?)] = [:]

    for item in metadata {
      guard let identifier = item.identifier?.rawValue else { continue }

      // Match CHAPTER001, CHAPTER002, etc. (without NAME suffix)
      if let range = identifier.range(of: #"CHAPTER(\d+)$"#, options: .regularExpression) {
        let matched = identifier[range]
        let numberStr = matched.dropFirst(7) // Remove "CHAPTER" prefix
        if let number = Int(numberStr) {
          let time = try? await item.load(.stringValue)
          chapterMap[number, default: (nil, nil)].time = time
        }
      }

      // Match CHAPTER001NAME, CHAPTER002NAME, etc.
      if let range = identifier.range(of: #"CHAPTER(\d+)NAME$"#, options: .regularExpression) {
        let matched = identifier[range]
        let numberStr = String(matched.dropFirst(7).dropLast(4)) // Remove "CHAPTER" and "NAME"
        if let number = Int(numberStr) {
          let name = try? await item.load(.stringValue)
          chapterMap[number, default: (nil, nil)].name = name
        }
      }
    }

    // Sort by chapter number and create ChapterMetadata objects
    let sortedChapters = chapterMap.sorted { $0.key < $1.key }
    var chapters: [ChapterMetadata] = []

    for (index, (_, data)) in sortedChapters.enumerated() {
      guard let timeString = data.time else { continue }

      let start = TimeParser.getDuration(from: timeString)
      let chapterDuration: TimeInterval

      // Calculate duration from next chapter or file duration
      if index < sortedChapters.count - 1,
         let nextTimeString = sortedChapters[index + 1].value.time {
        chapterDuration = TimeParser.getDuration(from: nextTimeString) - start
      } else {
        chapterDuration = duration - start
      }

      let chapter = ChapterMetadata(
        title: data.name ?? "",
        start: start,
        duration: chapterDuration,
        index: index + 1
      )

      chapters.append(chapter)
    }

    return chapters.isEmpty ? nil : chapters
  }

  private func extractID3Chapters(from metadata: [AVMetadataItem], duration: TimeInterval) async -> [ChapterMetadata]? {
    var chapterData: [(start: Double, title: String)] = []

    for item in metadata {
      guard let identifier = item.identifier?.rawValue,
            identifier.hasPrefix("id3/CHAP") else { continue }

      // Extract chapter start time and title from CHAP frame
      // Note: AVFoundation may not fully expose CHAP frame timing data currently,
      // but we attempt to load what's available for future compatibility.
      if let dateValue = try? await item.load(.dateValue) {
        let startTime = dateValue.timeIntervalSince1970
        let title = (try? await item.load(.stringValue)) ?? ""
        chapterData.append((start: startTime, title: title))
      }
    }

    // Sort chapters by start time
    chapterData.sort { $0.start < $1.start }

    var chapters: [ChapterMetadata] = []
    for (index, data) in chapterData.enumerated() {
      let chapterDuration: TimeInterval

      // Calculate duration
      if index < chapterData.count - 1 {
        chapterDuration = chapterData[index + 1].start - data.start
      } else {
        chapterDuration = duration - data.start
      }

      let chapter = ChapterMetadata(
        title: data.title,
        start: data.start,
        duration: chapterDuration,
        index: index + 1
      )

      chapters.append(chapter)
    }

    return chapters.isEmpty ? nil : chapters
  }

  private func extractOverdriveChapters(from metadata: [AVMetadataItem], duration: TimeInterval) async -> [ChapterMetadata]? {
    guard let txxxItem = metadata.first(where: { $0.identifier?.rawValue == "id3/TXXX" }),
          let overdriveMetadata = try? await txxxItem.load(.stringValue)
    else { return nil }

    let matches = overdriveMetadata.matches(of: /<Marker>(.+?)<\/Marker>/)
    var chapters: [ChapterMetadata] = []

    for (index, match) in matches.enumerated() {
      let (_, marker) = match.output

      guard let (_, timeMatch) = marker.matches(of: /<Time>(.+?)<\/Time>/).first?.output else {
        continue
      }

      let start = TimeParser.getDuration(from: String(timeMatch))
      let title: String
      
      if let (_, nameMatch) = marker.matches(of: /<Name>(.+?)<\/Name>/).first?.output {
        title = String(nameMatch)
      } else {
        title = ""
      }
      
      let chapter = ChapterMetadata(
        title: title,
        start: start,
        duration: 0, // Will be calculated below
        index: index + 1
      )

      chapters.append(chapter)
    }

    // Overdrive markers do not include the duration, we have to parse it from the next chapter over
    var finalChapters: [ChapterMetadata] = []
    for (index, chapter) in chapters.enumerated() {
      let chapterDuration: TimeInterval
      
      if index == chapters.endIndex - 1 {
        chapterDuration = duration - chapter.start
      } else {
        chapterDuration = chapters[index + 1].start - chapter.start
      }
      
      let updatedChapter = ChapterMetadata(
        title: chapter.title,
        start: chapter.start,
        duration: chapterDuration,
        index: chapter.index
      )

      finalChapters.append(updatedChapter)
    }

    return finalChapters.isEmpty ? nil : finalChapters
  }
}
