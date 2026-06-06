//
//  AudioMetadataService.swift
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

public protocol AudioMetadataServiceProtocol {
  /// Extract metadata from an audio file
  /// - Parameter fileURL: URL to the audio file
  /// - Returns: AudioMetadata if extraction succeeds, nil otherwise
  func extractMetadata(from fileURL: URL) async -> AudioMetadata?

  /// Extract metadata from an AVAsset
  /// - Parameter asset: The AVAsset to extract metadata from
  /// - Returns: AudioMetadata if extraction succeeds, nil otherwise
  func extractMetadata(from asset: AVAsset) async -> AudioMetadata?
}

public class AudioMetadataService: BPLogger, AudioMetadataServiceProtocol {

  /// File extensions whose containers can hold a QuickTime/MP4 text chapter track. This is
  /// an explicit list rather than a `UTType` conformance check on purpose: no system UTType
  /// models "ISO-BMFF container" — `m4b` resolves to `com.apple.protected-mpeg-4-audio-b`,
  /// which conforms to none of `.mpeg4Audio`/`.mpeg4Movie`/`.quickTimeMovie`, and the only
  /// broad-enough type, `.audiovisualContent`, also matches `mp3`/`flac`/`wav` (defeating the
  /// gate) while still missing the unregistered `aaxc` UTI.
  private static let quickTimeFileExtensions: Set<String> = ["m4b", "m4a", "mp4", "m4v", "mov", "aax", "aaxc"]

  /// Upper bound on a single chapter text sample we'll read from disk. Chapter titles are
  /// tiny; this caps memory use if a malformed `stsz` table declares an enormous sample.
  private static let maxChapterSampleSize = 64 * 1024

  /// Upper bound on the total number of samples we'll expand from a chapter track's tables.
  /// A 100-hour book at one chapter per minute is ~6,000 — this is generous headroom.
  private static let maxChapterSampleCount = 100_000

  /// Upper bound on the `moov` box we'll read into memory. Even chapter-rich audiobooks
  /// keep `moov` well under a megabyte; this caps memory if a file declares a huge one.
  private static let maxMoovSize = 256 * 1024 * 1024

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
      let chapters = await extractChapters(from: asset, metadata: metadata, duration: durationSeconds)

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
  
  private func extractChapters(from asset: AVAsset, metadata: [AVMetadataItem], duration: TimeInterval) async -> [ChapterMetadata]? {
    do {
      let availableChapterLocales = try await asset.load(.availableChapterLocales)

      // First try: Native chapter support (works for M4B, some M4A, properly tagged files).
      // If locales exist but yield no usable chapters, fall through to the manual fallbacks.
      if !availableChapterLocales.isEmpty,
         let standardChapters = await extractStandardChapters(from: asset, locales: availableChapterLocales) {
        return standardChapters
      }

      // Second try: Malformed QuickTime/MP4 chapter tracks that AVFoundation refuses
      // to expose. Older tools (e.g. "MarkAble") create a valid `chap`-referenced text
      // chapter track but tag it with an external `alis` data reference and/or an invalid
      // media language. AVFoundation then reports no `availableChapterLocales`, even though
      // the chapter samples are physically present in the file. Parse them directly.
      // Gated to MP4/QuickTime containers so non-MP4 files (e.g. MP3) skip the box scan.
      // The parser does blocking FileHandle I/O, so run it off the cooperative thread pool.
      // This runs during import while the user waits for the book to appear, so use
      // `.userInitiated` — `.utility` would let the OS throttle the disk reads.
      if let url = (asset as? AVURLAsset)?.url,
         Self.quickTimeFileExtensions.contains(url.pathExtension.lowercased()) {
        let textChapters = await withCheckedContinuation { continuation in
          DispatchQueue.global(qos: .userInitiated).async {
            continuation.resume(returning: self.extractQuickTimeTextChapters(from: url, duration: duration))
          }
        }
        if let textChapters {
          return textChapters
        }
      }

      // Third try: Check what metadata identifiers exist
      let identifiers = metadata.compactMap { $0.identifier?.rawValue }

      // FLAC/Vorbis chapters (CHAPTER tags)
      if identifiers.contains(where: { $0.contains("CHAPTER") && !$0.contains("NAME") }) {
        return await extractVorbisChapters(from: metadata, duration: duration)
      }

      // MP3 Overdrive chapters (ID3 TXXX tag)
      if identifiers.contains("id3/TXXX") {
        return await extractOverdriveChapters(from: metadata, duration: duration)
      }

      // MP3 standard chapters (ID3v2.3+ CHAP frames).
      // AVFoundation only assembles ID3 chapters into `availableChapterLocales` when a
      // `CTOC` (table of contents) frame is present. Without it, the `CHAP` frames are
      // surfaced only as opaque data blobs, so we parse them ourselves.
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
    // AVFoundation surfaces each CHAP frame as an opaque data blob (its `numberValue`
    // and `stringValue` are nil), so we parse the raw frame body ourselves. The CHAP
    // frame layout (ID3v2.3/2.4) is:
    //   element ID  : null-terminated string
    //   start time  : UInt32 BE, milliseconds
    //   end time    : UInt32 BE, milliseconds
    //   start offset: UInt32 BE, byte offset (0xFFFFFFFF when unused)
    //   end offset  : UInt32 BE, byte offset (0xFFFFFFFF when unused)
    //   sub-frames  : embedded ID3 frames (e.g. TIT2 for the chapter title)
    var chapterData: [(start: Double, end: Double?, title: String)] = []

    for item in metadata {
      guard let identifier = item.identifier?.rawValue,
            identifier.hasPrefix("id3/CHAP"),
            let data = try? await item.load(.dataValue) else { continue }

      if let parsed = parseID3ChapterFrame([UInt8](data)) {
        chapterData.append(parsed)
      }
    }

    // Sort chapters by start time
    chapterData.sort { $0.start < $1.start }

    var chapters: [ChapterMetadata] = []
    for (index, data) in chapterData.enumerated() {
      // Prefer the frame's own end time; otherwise derive from the next chapter or the
      // total duration. Guard against malformed end times that precede the start.
      let chapterDuration: TimeInterval
      if let end = data.end, end > data.start {
        chapterDuration = end - data.start
      } else if index < chapterData.count - 1 {
        chapterDuration = chapterData[index + 1].start - data.start
      } else {
        chapterDuration = duration - data.start
      }

      let chapter = ChapterMetadata(
        title: data.title,
        start: data.start,
        duration: max(0, chapterDuration),
        index: index + 1
      )

      chapters.append(chapter)
    }

    return chapters.isEmpty ? nil : chapters
  }

  /// Parse a single ID3 `CHAP` frame body into its start/end times (seconds) and title.
  private func parseID3ChapterFrame(_ body: [UInt8]) -> (start: Double, end: Double?, title: String)? {
    // Element ID is a null-terminated string.
    guard let terminator = body.firstIndex(of: 0) else { return nil }
    var cursor = terminator + 1

    // Need 16 bytes for the four UInt32 timing/offset fields.
    guard cursor + 16 <= body.count else { return nil }
    let startMS = beUInt32(body, cursor)
    let endMS = beUInt32(body, cursor + 4)
    cursor += 16

    let start = Double(startMS) / 1000.0
    // 0xFFFFFFFF / a non-increasing end signals "unset"; let the caller derive duration.
    let end: Double? = (endMS == 0xFFFFFFFF || endMS <= startMS) ? nil : Double(endMS) / 1000.0

    let title = parseID3ChapterTitle(body, from: cursor)
    return (start: start, end: end, title: title)
  }

  /// Walk the sub-frames of a CHAP frame and return the `TIT2` (title) text, if present.
  private func parseID3ChapterTitle(_ body: [UInt8], from start: Int) -> String {
    var cursor = start

    // Each sub-frame: 4-byte frame ID, 4-byte size, 2-byte flags, then the payload.
    while cursor + 10 <= body.count {
      let frameID = typeString(body, cursor)
      let payloadStart = cursor + 10

      // ID3v2.4 encodes frame sizes as synchsafe integers (every byte has bit 7 clear);
      // v2.3 uses a plain UInt32. The CHAP blob doesn't carry the tag version, so we infer
      // it: if all four size bytes have bit 7 clear the field is a valid synchsafe integer,
      // which agrees with the plain value below 128 and is the correct reading for v2.4.
      // Otherwise it can only be a plain v2.3 size. We fall back to the other interpretation
      // if the chosen one overruns the buffer.
      let plainSize = Int(beUInt32(body, cursor + 4))
      let synchsafeSize = Int(synchsafeUInt32(body, cursor + 4))
      let sizeBytesAreSynchsafe = (4...7).allSatisfy { (body[cursor + $0] & 0x80) == 0 }
      var size = sizeBytesAreSynchsafe ? synchsafeSize : plainSize
      if payloadStart + size > body.count {
        // The chosen interpretation overruns; the other one must be correct.
        size = sizeBytesAreSynchsafe ? plainSize : synchsafeSize
      } else if sizeBytesAreSynchsafe, plainSize != synchsafeSize, payloadStart + plainSize == body.count {
        // Ambiguous: the size bytes are valid synchsafe but also a valid plain UInt32. When
        // the plain size lands exactly on the frame boundary it's a v2.3 frame whose size
        // bytes happen to all have bit 7 clear (e.g. a 256-byte title) — prefer it.
        size = plainSize
      }
      guard size > 0, payloadStart + size <= body.count else { break }

      if frameID == "TIT2" {
        return decodeID3Text(Array(body[payloadStart..<payloadStart + size]))
      }

      cursor = payloadStart + size
    }

    return ""
  }

  /// Decode an ID3 text-frame payload (a leading encoding byte followed by the text).
  private func decodeID3Text(_ payload: [UInt8]) -> String {
    guard let encoding = payload.first else { return "" }
    var bytes = Array(payload.dropFirst())
    // Strip a trailing null terminator (one byte for 8-bit encodings, two for UTF-16).
    let trimmed: String

    switch encoding {
    case 0: // ISO-8859-1 (Latin-1)
      if bytes.last == 0 { bytes.removeLast() }
      trimmed = String(bytes: bytes, encoding: .isoLatin1) ?? ""
    case 1: // UTF-16 with BOM
      if bytes.count >= 2, bytes.count % 2 == 0, bytes[bytes.count - 1] == 0, bytes[bytes.count - 2] == 0 { bytes.removeLast(2) }
      trimmed = decodeUTF16WithBOM(bytes)
    case 2: // UTF-16BE without BOM
      if bytes.count >= 2, bytes.count % 2 == 0, bytes[bytes.count - 1] == 0, bytes[bytes.count - 2] == 0 { bytes.removeLast(2) }
      trimmed = String(bytes: bytes, encoding: .utf16BigEndian) ?? ""
    default: // 3 = UTF-8 (and any unknown value, treated leniently)
      if bytes.last == 0 { bytes.removeLast() }
      trimmed = String(bytes: bytes, encoding: .utf8) ?? ""
    }

    return trimmed
  }

  /// Decode UTF-16 bytes, honoring a leading BOM. The ID3 spec requires a BOM for this
  /// encoding, but some taggers omit it; we then default to little-endian (the common case
  /// for Windows-authored tags) before falling back to big-endian.
  private func decodeUTF16WithBOM(_ bytes: [UInt8]) -> String {
    if bytes.count >= 2 {
      if bytes[0] == 0xFF, bytes[1] == 0xFE {
        return String(bytes: bytes.dropFirst(2), encoding: .utf16LittleEndian) ?? ""
      }
      if bytes[0] == 0xFE, bytes[1] == 0xFF {
        return String(bytes: bytes.dropFirst(2), encoding: .utf16BigEndian) ?? ""
      }
    }
    return String(bytes: bytes, encoding: .utf16LittleEndian)
      ?? String(bytes: bytes, encoding: .utf16BigEndian)
      ?? ""
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

  // MARK: - QuickTime / MP4 text chapter track fallback

  /// Parse chapters from a QuickTime-style text chapter track by reading the MP4 box
  /// structure directly. Used when AVFoundation declines to expose chapters that are
  /// nonetheless present (malformed data reference or invalid track language).
  /// - Returns: The parsed chapters, or `nil` if the file has no readable text chapter track.
  private func extractQuickTimeTextChapters(from url: URL, duration: TimeInterval) -> [ChapterMetadata]? {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? handle.close() }

    guard
      let fileSize = try? handle.seekToEnd(),
      let moov = readTopLevelBox(named: "moov", handle: handle, fileSize: fileSize)
    else { return nil }

    // Gather every track, then resolve the one referenced as the chapter track.
    let traks = childBoxes(moov, 0, moov.count).filter { $0.type == "trak" }
    guard !traks.isEmpty else { return nil }

    var trackByID: [UInt32: (start: Int, end: Int)] = [:]
    var chapterTrackID: UInt32?

    for trak in traks {
      guard let trackID = trackID(of: moov, trak.start, trak.end) else { continue }
      trackByID[trackID] = (trak.start, trak.end)

      // A track's `tref` of type `chap` lists the IDs of its chapter tracks.
      if chapterTrackID == nil,
         let tref = firstChild(moov, trak.start, trak.end, "tref"),
         let chap = firstChild(moov, tref.start, tref.end, "chap"),
         chap.end >= chap.start + 4 {
        chapterTrackID = beUInt32(moov, chap.start)
      }
    }

    guard
      let chapterID = chapterTrackID,
      let chapterTrak = trackByID[chapterID]
    else { return nil }

    return parseTextChapters(
      moov: moov,
      trakStart: chapterTrak.start,
      trakEnd: chapterTrak.end,
      handle: handle,
      totalDuration: duration
    )
  }

  /// Parse the sample table of a text chapter track and read each chapter's title and timing.
  private func parseTextChapters(
    moov: [UInt8],
    trakStart: Int,
    trakEnd: Int,
    handle: FileHandle,
    totalDuration: TimeInterval
  ) -> [ChapterMetadata]? {
    guard
      let mdhd = descend(moov, trakStart, trakEnd, ["mdia", "mdhd"]),
      let stbl = descend(moov, trakStart, trakEnd, ["mdia", "minf", "stbl"])
    else { return nil }

    // mdhd timescale: version (0/1) changes the field offset. Guard the version-byte read
    // against a zero-payload mdhd box (mdhd.start could equal moov.count).
    guard mdhd.start < mdhd.end else { return nil }
    let mdhdVersion = moov[mdhd.start]
    let timescaleOffset = mdhd.start + (mdhdVersion == 1 ? 20 : 12)
    guard timescaleOffset + 4 <= mdhd.end else { return nil }
    let timescale = beUInt32(moov, timescaleOffset)
    guard timescale > 0 else { return nil }

    guard
      let sampleDeltas = parseSTTS(moov, stbl),
      let sampleSizes = parseSTSZ(moov, stbl),
      let chunkOffsets = parseChunkOffsets(moov, stbl),
      let sampleToChunk = parseSTSC(moov, stbl)
    else { return nil }

    let locations = sampleLocations(
      sizes: sampleSizes,
      chunkOffsets: chunkOffsets,
      sampleToChunk: sampleToChunk
    )
    // A well-formed chapter track has one stts duration per sample. If the tables
    // disagree (malformed), only trust as many samples as both tables describe so we
    // don't emit trailing chapters that all share the same timestamp.
    let sampleCount = min(locations.count, sampleDeltas.count)
    guard sampleCount > 0 else { return nil }

    // Sample start times are the cumulative sum of per-sample durations (stts), in
    // the track's timescale. Chapter durations are derived from consecutive starts so
    // that empty/degenerate samples don't produce negative or zero-length spans.
    var starts: [TimeInterval] = []
    var cumulative: UInt64 = 0
    for index in 0..<sampleCount {
      starts.append(TimeInterval(cumulative) / TimeInterval(timescale))
      cumulative += UInt64(sampleDeltas[index])
    }

    var chapters: [ChapterMetadata] = []
    for index in 0..<sampleCount {
      let location = locations[index]
      guard
        location.size >= 2,
        location.size <= Self.maxChapterSampleSize,
        let sampleData = readBytes(handle: handle, offset: location.offset, length: location.size),
        sampleData.count >= 2
      else { continue }

      let titleLength = Int(beUInt16([UInt8](sampleData), 0))
      let titleBytes = sampleData.dropFirst(2).prefix(titleLength)
      let title = decodeText(Array(titleBytes))

      let start = starts[index]
      let nextStart = index < starts.count - 1 ? starts[index + 1] : totalDuration
      let chapterDuration = max(0, nextStart - start)

      chapters.append(
        ChapterMetadata(
          title: title,
          start: start,
          duration: chapterDuration,
          index: index + 1
        )
      )
    }

    return chapters.isEmpty ? nil : chapters
  }

  // MARK: - Sample table parsing

  /// Per-sample durations expanded from the run-length encoded `stts` box.
  private func parseSTTS(_ data: [UInt8], _ stbl: (start: Int, end: Int)) -> [UInt32]? {
    guard let box = firstChild(data, stbl.start, stbl.end, "stts"), box.start + 8 <= box.end else { return nil }
    let entryCount = Int(beUInt32(data, box.start + 4))
    var deltas: [UInt32] = []
    var cursor = box.start + 8
    for _ in 0..<entryCount {
      guard cursor + 8 <= box.end else { break }
      let sampleCount = Int(beUInt32(data, cursor))
      let sampleDelta = beUInt32(data, cursor + 4)
      // Guard against pathological counts that would exhaust memory — bounded cumulatively,
      // since many entries could otherwise expand past the overall limit.
      guard deltas.count + sampleCount <= Self.maxChapterSampleCount else { return nil }
      deltas.append(contentsOf: repeatElement(sampleDelta, count: sampleCount))
      cursor += 8
    }
    return deltas
  }

  /// Per-sample byte sizes from the `stsz` box (handles the shared-size form).
  private func parseSTSZ(_ data: [UInt8], _ stbl: (start: Int, end: Int)) -> [Int]? {
    guard let box = firstChild(data, stbl.start, stbl.end, "stsz"), box.start + 12 <= box.end else { return nil }
    let uniformSize = beUInt32(data, box.start + 4)
    let sampleCount = Int(beUInt32(data, box.start + 8))
    guard sampleCount <= Self.maxChapterSampleCount else { return nil }

    if uniformSize != 0 {
      return Array(repeating: Int(uniformSize), count: sampleCount)
    }

    var sizes: [Int] = []
    var cursor = box.start + 12
    for _ in 0..<sampleCount {
      guard cursor + 4 <= box.end else { break }
      sizes.append(Int(beUInt32(data, cursor)))
      cursor += 4
    }
    return sizes
  }

  /// Chunk file offsets from `stco` (32-bit) or `co64` (64-bit).
  private func parseChunkOffsets(_ data: [UInt8], _ stbl: (start: Int, end: Int)) -> [UInt64]? {
    if let box = firstChild(data, stbl.start, stbl.end, "stco") {
      return chunkOffsets(data, box, entrySize: 4) { UInt64(beUInt32(data, $0)) }
    }
    if let box = firstChild(data, stbl.start, stbl.end, "co64") {
      return chunkOffsets(data, box, entrySize: 8) { beUInt64(data, $0) }
    }
    return nil
  }

  /// Shared `stco`/`co64` reader: walk `entrySize`-byte chunk offsets, decoding each with `read`.
  private func chunkOffsets(
    _ data: [UInt8],
    _ box: (start: Int, end: Int),
    entrySize: Int,
    read: (Int) -> UInt64
  ) -> [UInt64]? {
    guard box.start + 8 <= box.end else { return nil }
    let count = Int(beUInt32(data, box.start + 4))
    guard count <= Self.maxChapterSampleCount else { return nil }
    var offsets: [UInt64] = []
    var cursor = box.start + 8
    for _ in 0..<count {
      guard cursor + entrySize <= box.end else { break }
      offsets.append(read(cursor))
      cursor += entrySize
    }
    return offsets
  }

  /// `stsc` run table mapping chunk indices to samples-per-chunk.
  private func parseSTSC(_ data: [UInt8], _ stbl: (start: Int, end: Int)) -> [(firstChunk: Int, samplesPerChunk: Int)]? {
    guard let box = firstChild(data, stbl.start, stbl.end, "stsc"), box.start + 8 <= box.end else { return nil }
    let entryCount = Int(beUInt32(data, box.start + 4))
    guard entryCount <= Self.maxChapterSampleCount else { return nil }
    var entries: [(Int, Int)] = []
    var cursor = box.start + 8
    for _ in 0..<entryCount {
      guard cursor + 12 <= box.end else { break }
      let firstChunk = Int(beUInt32(data, cursor))
      let samplesPerChunk = Int(beUInt32(data, cursor + 4))
      entries.append((firstChunk, samplesPerChunk))
      cursor += 12
    }
    return entries.isEmpty ? nil : entries
  }

  /// Resolve each sample's absolute file offset and size by walking chunks (stsc + stco + stsz).
  private func sampleLocations(
    sizes: [Int],
    chunkOffsets: [UInt64],
    sampleToChunk: [(firstChunk: Int, samplesPerChunk: Int)]
  ) -> [(offset: UInt64, size: Int)] {
    var locations: [(UInt64, Int)] = []
    var sampleIndex = 0

    for chunkIndex in 0..<chunkOffsets.count {
      // The applicable run is the last entry whose firstChunk <= this chunk (1-based).
      let chunkNumber = chunkIndex + 1
      var samplesPerChunk = sampleToChunk[0].samplesPerChunk
      for entry in sampleToChunk {
        if entry.firstChunk <= chunkNumber {
          samplesPerChunk = entry.samplesPerChunk
        } else {
          break
        }
      }

      var offsetWithinChunk = chunkOffsets[chunkIndex]
      for _ in 0..<samplesPerChunk {
        guard sampleIndex < sizes.count else { return locations }
        let size = sizes[sampleIndex]
        locations.append((offsetWithinChunk, size))
        offsetWithinChunk += UInt64(size)
        sampleIndex += 1
      }
    }

    return locations
  }

  // MARK: - Box navigation helpers

  /// Scan top-level boxes and return the payload bytes of the first box with the given type.
  private func readTopLevelBox(named name: String, handle: FileHandle, fileSize: UInt64) -> [UInt8]? {
    var offset: UInt64 = 0
    while offset + 8 <= fileSize {
      try? handle.seek(toOffset: offset)
      guard
        let headerData = try? handle.read(upToCount: 16),
        headerData.count >= 8
      else { return nil }

      let header = [UInt8](headerData)
      let size32 = beUInt32(header, 0)
      var boxSize = UInt64(size32)
      var headerSize: UInt64 = 8

      if size32 == 1 {
        guard header.count >= 16 else { return nil }
        boxSize = beUInt64(header, 8)
        headerSize = 16
      } else if size32 == 0 {
        boxSize = fileSize - offset
      }

      // A box must be at least its header and must fit within the remaining file. This
      // also prevents both a UInt64->Int overflow trap below and an `offset` wraparound
      // (an infinite loop) when a malformed file declares an absurd box size.
      guard boxSize >= headerSize, boxSize <= fileSize - offset else { return nil }

      if typeString(header, 4) == name {
        let payloadLength = Int(boxSize - headerSize)
        // Don't read an absurdly large box into memory.
        guard payloadLength <= Self.maxMoovSize else { return nil }
        try? handle.seek(toOffset: offset + headerSize)
        guard
          let payload = try? handle.read(upToCount: payloadLength),
          payload.count == payloadLength
        else { return nil }
        return [UInt8](payload)
      }

      offset += boxSize
    }
    return nil
  }

  /// Immediate child boxes within the byte range `[start, end)`.
  private func childBoxes(_ data: [UInt8], _ start: Int, _ end: Int) -> [(type: String, start: Int, end: Int)] {
    var children: [(String, Int, Int)] = []
    var cursor = start
    while cursor + 8 <= end {
      let size32 = beUInt32(data, cursor)
      var size = Int(size32)
      var headerSize = 8
      if size32 == 1 {
        guard cursor + 16 <= end else { break }
        // Clamp to the enclosing range so an oversized 64-bit size can't trap on the
        // UInt64->Int conversion; the bounds guard below then rejects it.
        let extendedSize = beUInt64(data, cursor + 8)
        size = extendedSize > UInt64(end - cursor) ? (end - cursor + 1) : Int(extendedSize)
        headerSize = 16
      } else if size32 == 0 {
        size = end - cursor
      }
      guard size >= headerSize, cursor + size <= end else { break }
      children.append((typeString(data, cursor + 4), cursor + headerSize, cursor + size))
      cursor += size
    }
    return children
  }

  /// The first immediate child box of the given type within `[start, end)`.
  private func firstChild(_ data: [UInt8], _ start: Int, _ end: Int, _ type: String) -> (start: Int, end: Int)? {
    for child in childBoxes(data, start, end) where child.type == type {
      return (child.start, child.end)
    }
    return nil
  }

  /// Follow a chain of nested child box types, returning the innermost range.
  private func descend(_ data: [UInt8], _ start: Int, _ end: Int, _ path: [String]) -> (start: Int, end: Int)? {
    var current = (start: start, end: end)
    for type in path {
      guard let next = firstChild(data, current.start, current.end, type) else { return nil }
      current = next
    }
    return current
  }

  /// Read a track's ID from its `tkhd` box (version 0 and 1 layouts differ).
  private func trackID(of data: [UInt8], _ trakStart: Int, _ trakEnd: Int) -> UInt32? {
    guard let tkhd = firstChild(data, trakStart, trakEnd, "tkhd"), tkhd.start < tkhd.end else { return nil }
    let version = data[tkhd.start]
    let trackIDOffset = tkhd.start + (version == 1 ? 20 : 12)
    guard trackIDOffset + 4 <= tkhd.end else { return nil }
    return beUInt32(data, trackIDOffset)
  }

  // MARK: - Primitive readers

  /// Decode QuickTime text sample bytes, trying UTF-16 (when a BOM is present), then
  /// UTF-8, then Mac Roman (the legacy default for text tracks).
  private func decodeText(_ bytes: [UInt8]) -> String {
    guard !bytes.isEmpty else { return "" }

    if bytes.count >= 2, (bytes[0] == 0xFE && bytes[1] == 0xFF) || (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      if let utf16 = String(bytes: bytes, encoding: .utf16) { return utf16 }
    }
    if let utf8 = String(bytes: bytes, encoding: .utf8) { return utf8 }
    if let macRoman = String(bytes: bytes, encoding: .macOSRoman) { return macRoman }
    return String(bytes: bytes, encoding: .isoLatin1) ?? ""
  }

  private func readBytes(handle: FileHandle, offset: UInt64, length: Int) -> Data? {
    guard length > 0, (try? handle.seek(toOffset: offset)) != nil else { return nil }
    return try? handle.read(upToCount: length)
  }

  private func beUInt16(_ data: [UInt8], _ offset: Int) -> UInt16 {
    guard offset + 2 <= data.count else { return 0 }
    return (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
  }

  private func beUInt32(_ data: [UInt8], _ offset: Int) -> UInt32 {
    guard offset + 4 <= data.count else { return 0 }
    return (UInt32(data[offset]) << 24)
      | (UInt32(data[offset + 1]) << 16)
      | (UInt32(data[offset + 2]) << 8)
      | UInt32(data[offset + 3])
  }

  /// Read a 28-bit ID3v2 synchsafe integer (7 bits per byte, MSB always zero).
  private func synchsafeUInt32(_ data: [UInt8], _ offset: Int) -> UInt32 {
    guard offset + 4 <= data.count else { return 0 }
    return (UInt32(data[offset] & 0x7F) << 21)
      | (UInt32(data[offset + 1] & 0x7F) << 14)
      | (UInt32(data[offset + 2] & 0x7F) << 7)
      | UInt32(data[offset + 3] & 0x7F)
  }

  private func beUInt64(_ data: [UInt8], _ offset: Int) -> UInt64 {
    guard offset + 8 <= data.count else { return 0 }
    var value: UInt64 = 0
    for index in 0..<8 {
      value = (value << 8) | UInt64(data[offset + index])
    }
    return value
  }

  private func typeString(_ data: [UInt8], _ offset: Int) -> String {
    guard offset + 4 <= data.count else { return "" }
    return String(bytes: data[offset..<offset + 4], encoding: .isoLatin1) ?? ""
  }
}
