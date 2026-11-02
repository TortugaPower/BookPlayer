//
//  MediaServerStreamsTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// Mirrors the Android app's `AudiobookshelfStreamFilesTest` and the naming half of
/// `VirtualImportManagerTest`: AudiobookShelf streams per file, looked up when a book plays or
/// downloads, and both apps name what a stream import creates the same way.
final class MediaServerStreamsTests: XCTestCase {
  private let serverURL = URL(string: "https://media.example.com/abs")!

  // MARK: - Names

  func testANameIsMadeSafeAsOnePathComponent() {
    XCTAssertEqual(MediaServerFileNames.sanitize("AC/DC: Live?"), "AC_DC_ Live")
    XCTAssertEqual(MediaServerFileNames.sanitize("a<>b"), "a_b")
    XCTAssertEqual(MediaServerFileNames.sanitize("..hidden."), "hidden")
    XCTAssertEqual(MediaServerFileNames.sanitize("///"), "untitled_file")
  }

  func testASingleBookIsNamedAfterItsTitleAndRealExtension() {
    XCTAssertEqual(MediaServerFileNames.importFileName(title: "Dune", fileExtension: ".m4b"), "Dune.m4b")
    XCTAssertEqual(MediaServerFileNames.importFileName(title: "Dune", fileExtension: "mp3"), "Dune.mp3")
    XCTAssertEqual(MediaServerFileNames.importFileName(title: "1/2 Life", fileExtension: "mp3"), "1_2 Life.mp3")
  }

  func testAVolumesBooksAreNamedByTheirFlattenedPath() {
    XCTAssertEqual(
      MediaServerFileNames.volumeChildFileNames(["Disc 1/01.mp3", "Disc 2/01.mp3", "Bonus.mp3"]),
      ["Disc 1 - 01.mp3", "Disc 2 - 01.mp3", "Bonus.mp3"]
    )
  }

  /// Two paths that flatten to one name: the later ones get `-2`, `-3`.
  func testDuplicateFlattenedNamesGetASuffix() {
    XCTAssertEqual(
      MediaServerFileNames.volumeChildFileNames(["A/B.mp3", "A - B.mp3", "A/B.mp3", "notes"]),
      ["A - B.mp3", "A - B-2.mp3", "A - B-3.mp3", "notes"]
    )
    XCTAssertEqual(MediaServerFileNames.volumeChildFileNames(["notes", "notes"]), ["notes", "notes-2"])
  }

  /// Split at the last dot, as Android splits: an "extension" with a space is still one.
  func testASuffixGoesBeforeTheLastDotAsOnAndroid() {
    XCTAssertEqual(
      MediaServerFileNames.volumeChildFileNames(["Chapter 1. Intro", "Chapter 1. Intro"]),
      ["Chapter 1. Intro", "Chapter 1-2. Intro"]
    )
    XCTAssertEqual(MediaServerFileNames.splitExtension("Vol. 2").stem, "Vol")
    XCTAssertEqual(MediaServerFileNames.splitExtension("notes").fileExtension, "")
  }

  // MARK: - Tracks

  func testTracksStreamInIndexOrderFromTheirInode() throws {
    let files = try streamFiles(
      """
      [
        {"index": 2, "ino": "222", "duration": 20.5, "metadata": {"filename": "02.mp3", "relPath": "Disc 1/02.mp3"}},
        {"index": 1, "ino": "111", "duration": 10, "metadata": {"filename": "01.mp3", "relPath": "Disc 1/01.mp3"}}
      ]
      """
    )

    XCTAssertEqual(files, [
      ExternalStreamFile(path: "api/items/li_1/file/111", name: "Disc 1/01.mp3", duration: 10),
      ExternalStreamFile(path: "api/items/li_1/file/222", name: "Disc 1/02.mp3", duration: 20.5),
    ])
  }

  /// ABS 2.3–2.17 tracks don't carry `ino`: it's the end of their `contentUrl`, which carries the
  /// router base path and may have a query.
  func testAPre218TrackTakesItsInodeFromItsContentUrl() throws {
    let files = try streamFiles(
      """
      [
        {"index": 1, "ino": " ", "duration": 5, "contentUrl": "/abs/api/items/li_1/file/333?token=x", "metadata": {"filename": "a.m4b", "relPath": "  "}},
        {"index": 2, "duration": 5, "contentUrl": "/s/item/li_1/b.m4b", "metadata": {"filename": "b.m4b"}}
      ]
      """
    )

    XCTAssertEqual(files, [ExternalStreamFile(path: "api/items/li_1/file/333", name: "a.m4b", duration: 5)])
  }

  /// Built from the saved URL, so a reverse-proxy subpath survives.
  func testAFilesURLKeepsTheServersSubpath() {
    let file = ExternalStreamFile(path: "api/items/li_1/file/111", name: "a.mp3", duration: 1)

    XCTAssertEqual(file.url(on: serverURL).absoluteString, "https://media.example.com/abs/api/items/li_1/file/111")
  }

  // MARK: - Lookup

  func testALookupAsksForTheExpandedItemWithTheConnectionsHeaders() async throws {
    let http = StreamHTTPStub(status: 200, body: Self.itemJSON)
    let sut = AudiobookShelfStreamLookup(httpClient: http)

    let result = await sut.files(
      ofItem: "li_1",
      on: serverURL,
      headers: ["Authorization": "Bearer t", "CF-Access-Client-Id": "abc"],
      timeout: 5
    )

    XCTAssertEqual(result, .answered([ExternalStreamFile(path: "api/items/li_1/file/111", name: "01.mp3", duration: 10)]))
    let request = try XCTUnwrap(http.requests.first)
    XCTAssertEqual(request.url?.absoluteString, "https://media.example.com/abs/api/items/li_1?expanded=1")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer t")
    XCTAssertEqual(request.value(forHTTPHeaderField: "CF-Access-Client-Id"), "abc")
    XCTAssertNil(request.url?.query?.range(of: "token"), "the token rides the header, never the URL")
  }

  func testOnlyA401IsAnExpiredSession() async {
    let rejected = await AudiobookShelfStreamLookup(httpClient: StreamHTTPStub(status: 401))
      .files(ofItem: "li_1", on: serverURL, headers: [:], timeout: 5)
    XCTAssertEqual(rejected, .sessionExpired)

    // ABS answers 403 when this user may not open this item (a restricted library or tag)
    let forbidden = await AudiobookShelfStreamLookup(httpClient: StreamHTTPStub(status: 403))
      .files(ofItem: "li_1", on: serverURL, headers: [:], timeout: 5)
    XCTAssertEqual(forbidden, .failed)
  }

  func testAnItemTheServerNoLongerHasHasNoFiles() async {
    let result = await AudiobookShelfStreamLookup(httpClient: StreamHTTPStub(status: 404))
      .files(ofItem: "li_1", on: serverURL, headers: [:], timeout: 5)

    XCTAssertEqual(result, .answered([]))
  }

  func testAnAnswerThatIsntAnItemFails() async {
    let result = await AudiobookShelfStreamLookup(httpClient: StreamHTTPStub(status: 200, body: "<html>Sign in</html>"))
      .files(ofItem: "li_1", on: serverURL, headers: [:], timeout: 5)

    XCTAssertEqual(result, .failed)
  }

  func testAServerThatCantBeReachedIsUnreachable() async {
    let result = await AudiobookShelfStreamLookup(httpClient: StreamHTTPStub(error: URLError(.cannotConnectToHost)))
      .files(ofItem: "li_1", on: serverURL, headers: [:], timeout: 5)

    XCTAssertEqual(result, .unreachable)
  }

  /// The request's own timeout bounds only the gaps between packets: the lookup bounds the whole
  /// answer, so an unreachable home server falls through to the cloud copy quickly.
  func testALookupGivesUpAfterItsTimeout() async {
    let started = Date()
    let result = await AudiobookShelfStreamLookup(httpClient: StreamHTTPStub(status: 200, body: Self.itemJSON, delay: 10))
      .files(ofItem: "li_1", on: serverURL, headers: [:], timeout: 0.2)

    XCTAssertEqual(result, .unreachable)
    XCTAssertLessThan(Date().timeIntervalSince(started), 5)
  }

  // MARK: - Which file a book plays (Android's MediaServerStreamsTest)

  private let threeFiles = [
    ExternalStreamFile(path: "api/items/li_1/file/1", name: "Disc 1/01.mp3", duration: 10),
    ExternalStreamFile(path: "api/items/li_1/file/2", name: "Disc 2/01.mp3", duration: 10),
    ExternalStreamFile(path: "api/items/li_1/file/3", name: "Disc 1 - 01.mp3", duration: 10),
  ]

  private func lookup(_ member: PlayableChapter.StreamLookup.Member) -> PlayableChapter.StreamLookup {
    PlayableChapter.StreamLookup(serverURL: serverURL, itemId: "li_1", member: member)
  }

  /// A book plays one file. An item with several imported as one book (before volumes) has none
  /// of its own: playing only the first would be worse than saying it can't play.
  func testALinkedBookPlaysTheItemsOnlyFile() {
    XCTAssertEqual(lookup(.item).file(in: [threeFiles[0]]), threeFiles[0])
    XCTAssertNil(lookup(.item).file(in: threeFiles))
    XCTAssertNil(lookup(.item).file(in: []))
  }

  /// By the name it was imported under, rebuilt from the server's current files: a `-2` name
  /// still finds its file.
  func testAVolumesBookFindsTheFileItWasNamedAfter() {
    XCTAssertEqual(
      lookup(.volumeBook(fileName: "Disc 1 - 01-2.mp3", position: 0, bookCount: 3)).file(in: threeFiles),
      threeFiles[2]
    )
    XCTAssertEqual(
      lookup(.volumeBook(fileName: "Disc 2 - 01.mp3", position: 0, bookCount: 3)).file(in: threeFiles),
      threeFiles[1]
    )
  }

  /// Renamed on the server: the book at the same position, but only while the counts match.
  func testAVolumesBookFallsBackToItsPositionWhenTheCountsMatch() {
    XCTAssertEqual(
      lookup(.volumeBook(fileName: "renamed.mp3", position: 1, bookCount: 3)).file(in: threeFiles),
      threeFiles[1]
    )
    XCTAssertNil(lookup(.volumeBook(fileName: "renamed.mp3", position: 1, bookCount: 2)).file(in: threeFiles))
  }

  // MARK: - Playback: a volume lends its link to its books

  private struct ResolverStub: ExternalStreamResolving {
    let source: ExternalStreamSource?
    func streamSource(for resource: SimpleExternalResource) -> ExternalStreamSource? { source }
  }

  private func absResource(hostId: String = "https://abs.example.com") -> SimpleExternalResource {
    SimpleExternalResource(
      providerName: "audiobookshelf",
      providerId: "li_1",
      syncStatus: ExternalResource.SyncStatus.stream.rawValue,
      lastSyncedAt: nil,
      hostId: hostId
    )
  }

  private func item(
    _ relativePath: String,
    type: SimpleItemType,
    uuid: String = UUID().uuidString,
    resources: [SimpleExternalResource]? = nil
  ) -> SimpleLibraryItem {
    SimpleLibraryItem(
      title: (relativePath as NSString).lastPathComponent,
      details: "Author",
      speed: 1,
      currentTime: 0,
      duration: 10,
      percentCompleted: 0,
      isFinished: false,
      relativePath: relativePath,
      remoteURL: nil,
      artworkURL: nil,
      orderRank: 0,
      parentFolder: nil,
      originalFileName: (relativePath as NSString).lastPathComponent,
      lastPlayDate: nil,
      type: type,
      uuid: uuid,
      externalResources: resources
    )
  }

  /// Counts the resolves: each one reads the keychain
  private final class CountingResolver: ExternalStreamResolving {
    let source: ExternalStreamSource?
    private(set) var calls = 0

    init(source: ExternalStreamSource?) {
      self.source = source
    }

    func streamSource(for resource: SimpleExternalResource) -> ExternalStreamSource? {
      calls += 1
      return source
    }
  }

  private func playableChapters(
    of folder: SimpleLibraryItem,
    source: ExternalStreamSource?,
    resolver: ExternalStreamResolving? = nil
  ) throws -> [PlayableChapter] {
    let libraryService = LibraryServiceProtocolMock()
    libraryService.getChaptersFromReturnValue = [SimpleChapter(title: "Chapter", start: 0, duration: 10, index: 1)]
    libraryService.fetchContentsAtLimitOffsetReturnValue = [
      item("Vol/Disc 1 - 01.mp3", type: .book, uuid: "b1"),
      item("Vol/Disc 2 - 01.mp3", type: .book, uuid: "b2"),
    ]
    let sut = PlaybackService()
    sut.setup(libraryService: libraryService, streamResolver: resolver ?? ResolverStub(source: source))

    return try sut.getPlayableChapters(folder: folder)
  }

  /// The volume's link is resolved once per load, not once per book
  func testAVolumesLinkIsResolvedOncePerLoad() throws {
    let resolver = CountingResolver(source: ExternalStreamSource(
      location: .audiobookshelfItem(serverURL: serverURL, itemId: "li_1"),
      headers: [:]
    ))

    let chapters = try playableChapters(
      of: item("Vol", type: .bound, resources: [absResource()]),
      source: nil,
      resolver: resolver
    )

    XCTAssertEqual(chapters.count, 2)
    XCTAssertTrue(chapters.allSatisfy(\.isStreamed))
    XCTAssertEqual(resolver.calls, 1)
  }

  func testAVolumesBooksStreamThroughTheVolumesLink() throws {
    let source = ExternalStreamSource(
      location: .audiobookshelfItem(serverURL: serverURL, itemId: "li_1"),
      headers: ["Authorization": "Bearer t"]
    )

    let chapters = try playableChapters(of: item("Vol", type: .bound, resources: [absResource()]), source: source)

    XCTAssertEqual(chapters.map(\.streamLookup), [
      lookup(.volumeBook(fileName: "Disc 1 - 01.mp3", position: 0, bookCount: 2)),
      lookup(.volumeBook(fileName: "Disc 2 - 01.mp3", position: 1, bookCount: 2)),
    ])
    XCTAssertEqual(chapters.first?.externalHeaders["Authorization"], "Bearer t")
    XCTAssertTrue(chapters.allSatisfy { $0.isStreamed && !$0.hasUnresolvedExternalHost })
  }

  /// No saved server for the volume's link: its books say which server to add.
  func testAVolumeWithoutItsServerNamesItForEveryBook() throws {
    let chapters = try playableChapters(of: item("Vol", type: .bound, resources: [absResource()]), source: nil)

    XCTAssertTrue(chapters.allSatisfy { !$0.isStreamed })
    XCTAssertEqual(chapters.map(\.unresolvedHost?.address), ["https://abs.example.com", "https://abs.example.com"])
  }

  /// A plain folder's books are separate items: its link, if any, isn't theirs.
  func testAPlainFolderDoesntLendItsLink() throws {
    let source = ExternalStreamSource(
      location: .audiobookshelfItem(serverURL: serverURL, itemId: "li_1"),
      headers: [:]
    )

    let chapters = try playableChapters(of: item("Vol", type: .folder, resources: [absResource()]), source: source)

    XCTAssertTrue(chapters.allSatisfy { $0.streamLookup == nil && !$0.hasUnresolvedExternalHost })
  }

  /// One Jellyfin URL serves a whole item, so a volume's books can't play it.
  func testAJellyfinURLIsntLentToAVolumesBooks() throws {
    let source = ExternalStreamSource(url: URL(string: "https://jelly.example.com/stream")!, headers: [:])

    let chapters = try playableChapters(of: item("Vol", type: .bound, resources: [absResource()]), source: source)

    XCTAssertTrue(chapters.allSatisfy { !$0.isStreamed })
  }

  // MARK: - Downloads (Android's DownloadFileProcessorTest)

  private func planner(
    source: ExternalStreamSource?,
    answer: ExternalStreamFiles,
    books: [SyncableItem] = []
  ) -> (MediaServerDownloadPlanner, LookupStub) {
    let lookup = LookupStub(answer: answer)
    return (
      MediaServerDownloadPlanner(streamResolver: ResolverStub(source: source), streamLookup: lookup, volumeBooks: { _ in books }),
      lookup
    )
  }

  private let absSource = ExternalStreamSource(
    location: .audiobookshelfItem(serverURL: URL(string: "https://media.example.com/abs")!, itemId: "li_1"),
    headers: ["Authorization": "Bearer t"]
  )

  private func syncBook(_ relativePath: String, rank: Int) -> SyncableItem {
    SyncableItem(
      relativePath: relativePath,
      remoteURL: nil,
      artworkURL: nil,
      originalFileName: (relativePath as NSString).lastPathComponent,
      title: "t",
      details: "d",
      speed: nil,
      currentTime: 0,
      duration: 10,
      percentCompleted: 0,
      isFinished: false,
      orderRank: rank,
      lastPlayDateTimestamp: nil,
      type: .book,
      uuid: relativePath
    )
  }

  /// A volume downloads all its books with one lookup, each with the volume's server auth, and
  /// gets a folder to land them in.
  func testAVolumeDownloadsEveryBookFromOneLookup() async throws {
    let (sut, lookup) = planner(
      source: absSource,
      answer: .answered(Array(threeFiles.prefix(2))),
      books: [syncBook("Vol/Disc 2 - 01.mp3", rank: 1), syncBook("Vol/Disc 1 - 01.mp3", rank: 0)]
    )

    let downloads = try await sut.downloads(for: item("Vol", type: .bound, resources: [absResource()]), resource: absResource())

    XCTAssertEqual(lookup.calls, 1)
    XCTAssertEqual(lookup.timeouts, [ExternalStreamLookupTimeout.download], "a download's lookup waits longer than playback's")
    XCTAssertEqual(downloads.map(\.remoteURL.relativePath), ["Vol", "Vol/Disc 1 - 01.mp3", "Vol/Disc 2 - 01.mp3"])
    XCTAssertEqual(downloads[1].remoteURL.url.absoluteString, "https://media.example.com/abs/api/items/li_1/file/1")
    XCTAssertEqual(downloads[2].remoteURL.headers?["Authorization"], "Bearer t")
    XCTAssertNotNil(downloads[1].lookup, "a replaced file can be looked up again")
  }

  /// Asking again won't change these: the download is refused, not retried.
  func testAnItemTheServerNoLongerHasOrAMultiFileBookHasNothingToDownload() async {
    for answer in [ExternalStreamFiles.answered([]), .answered(threeFiles)] {
      let (sut, _) = planner(source: absSource, answer: answer)
      do {
        _ = try await sut.downloads(for: item("Book.mp3", type: .book), resource: absResource())
        XCTFail("expected no file for \(answer)")
      } catch {
        XCTAssertEqual(error as? MediaServerDownloadError, .noFile)
      }
    }
  }

  /// Each failed lookup says why, in the app's words rather than a URL error code.
  func testAFailedLookupSaysWhyTheDownloadCantStart() async {
    for (answer, expected) in [
      (ExternalStreamFiles.unreachable, MediaServerDownloadError.unreachable),
      (.failed, .refused),
    ] {
      let (sut, _) = planner(source: absSource, answer: answer)
      do {
        _ = try await sut.downloads(for: item("Book.mp3", type: .book), resource: absResource())
        XCTFail("expected \(expected)")
      } catch {
        XCTAssertEqual(error as? MediaServerDownloadError, expected)
        XCTAssertNotNil((error as? LocalizedError)?.errorDescription)
      }
    }
  }

  func testADownloadSaysWhenTheSessionExpired() async {
    let (sut, _) = planner(source: absSource, answer: .sessionExpired)

    do {
      _ = try await sut.downloads(for: item("Book.mp3", type: .book), resource: absResource())
      XCTFail("expected an expired session")
    } catch {
      XCTAssertEqual(error as? MediaServerDownloadError, .sessionExpired)
    }
  }

  /// No saved server for the link: nothing to plan, and the caller says which server is missing.
  func testADownloadWithoutItsServerPlansNothing() async throws {
    let (sut, lookup) = planner(source: nil, answer: .answered(threeFiles))

    let downloads = try await sut.downloads(for: item("Book.mp3", type: .book), resource: absResource())

    XCTAssertTrue(downloads.isEmpty)
    XCTAssertEqual(lookup.calls, 0)
  }

  // MARK: - Helpers

  private static let itemJSON = """
    {"id": "li_1", "media": {"tracks": [{"index": 1, "ino": "111", "duration": 10, "metadata": {"filename": "01.mp3"}}]}}
    """

  private func streamFiles(_ tracksJSON: String) throws -> [ExternalStreamFile] {
    let tracks = try JSONDecoder().decode([AudiobookShelfAPIItem.Media.Track].self, from: Data(tracksJSON.utf8))

    return AudiobookShelfAPIItem.Media.Track.streamFiles(itemId: "li_1", tracks: tracks)
  }
}

/// `@unchecked Sendable`: a test double whose knobs are set before use; the lookup reads it from
/// one task at a time.
private final class StreamHTTPStub: IntegrationHTTPClient, @unchecked Sendable {
  private let status: Int
  private let body: String
  private let error: Error?
  private let delay: TimeInterval
  private(set) var requests = [URLRequest]()

  init(status: Int = 200, body: String = "", error: Error? = nil, delay: TimeInterval = 0) {
    self.status = status
    self.body = body
    self.error = error
    self.delay = delay
  }

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    requests.append(request)
    if delay > 0 {
      try await Task.sleep(for: .seconds(delay))
    }
    if let error {
      throw error
    }

    return (
      Data(body.utf8),
      HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    )
  }

  func redirectLocation(for request: URLRequest) async throws -> URL {
    throw URLError(.unsupportedURL)
  }
}

/// Answers every lookup the same way, counting them.
final class LookupStub: ExternalStreamLooking, @unchecked Sendable {
  private let answer: ExternalStreamFiles
  private(set) var calls = 0
  private(set) var timeouts = [TimeInterval]()

  init(answer: ExternalStreamFiles) {
    self.answer = answer
  }

  func files(
    ofItem itemId: String,
    on serverURL: URL,
    headers: [String: String],
    timeout: TimeInterval
  ) async -> ExternalStreamFiles {
    calls += 1
    timeouts.append(timeout)
    return answer
  }
}
