//
//  HardcoverService.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/27/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import os
import UIKit

protocol HardcoverServiceProtocol {
  /// API key for API requests, stored without the `Bearer` scheme the requests add
  var authorization: String? { get set }

  /// Connected to Hardcover, with an API key or by signing in (OAuth)
  var isConnected: Bool { get }

  /// Connected by signing in, not with an API key
  var isSignedInWithOAuth: Bool { get }

  /// The connected account's Hardcover username, once read from `me`
  var connectedUsername: String? { get }

  /// Signed in without everything the app now asks for (a sign-in from an older version):
  /// signing in again grants the rest
  var needsSignInAgain: Bool { get }

  /// Sign in through Hardcover's authorize page, replacing an API key.
  /// - Parameter authenticate: opens the page and returns the redirect back to the app
  func signIn(authenticate: (URL) async throws -> URL) async throws

  /// Disconnect: revoke a sign-in and forget the API key
  func disconnect() async

  /// Search for books using the Hardcover API
  /// - Parameters:
  ///   - item: The library item to build search query from
  ///   - perPage: Number of results per page
  /// - Returns: BooksData containing search results
  func getBooks(for item: SimpleLibraryItem, perPage: Int) async throws -> BooksData

  /// Search for books using a custom search query
  /// - Parameters:
  ///   - query: The search query string
  ///   - perPage: Number of results per page
  /// - Returns: BooksData containing search results
  func searchBooks(query: String, perPage: Int) async throws -> BooksData

  /// Auto-match newly imported books with Hardcover if enabled
  /// Uses smart duplicate detection to avoid matching multiple files to the same book
  /// - Parameters:
  ///   - items: The newly imported library items (processes book items only)
  func processAutoMatch(for items: [SimpleLibraryItem]) async

  /// Assign a Hardcover book to a library item
  /// - Parameters:
  ///   - book: The Hardcover book to assign (nil to remove assignment)
  ///   - item: The library item to assign it to
  func assignItem(_ book: SimpleHardcoverBook?, to item: SimpleLibraryItem) async

  /// Remove a book from the user's Hardcover library
  /// - Parameter book: The Hardcover book to remove from library
  func removeFromLibrary(_ book: SimpleHardcoverBook) async throws

  /// Fetch a single book's info from Hardcover by its id
  /// - Parameter id: The Hardcover book id (the external resource's providerId)
  /// - Returns: The book info, or nil if not found
  func getBook(id: Int) async throws -> SimpleHardcoverBook?
}

@Observable
final class HardcoverService: BPLogger, HardcoverServiceProtocol {
  private var keychain: KeychainServiceProtocol!
  @ObservationIgnored private var oauthSession: HardcoverOAuthSession!
  @ObservationIgnored private var graphQL: GraphQLClient!
  private var audioMetadataService: AudioMetadataServiceProtocol!
  private var libraryService: LibraryServiceProtocol!
  /// IUO like its siblings (two-step init()+setup() DI): always injected by
  /// AppServices in production. Deliberately NOT optional — the schedule calls below
  /// are the sync-up for Hardcover-driven changes, and optional chaining would turn a
  /// missed injection into silently un-synced changes instead of a loud failure.
  private var syncService: SyncServiceProtocol!

  /// Internal bookkeeping, not state any view reads: kept out of observation, so progress ticks
  /// don't go through the registrar. Changed on the main queue only
  @ObservationIgnored private var metadataSubscription: AnyCancellable?
  @ObservationIgnored private var progressSubscription: AnyCancellable?
  @ObservationIgnored private var pauseSubscription: AnyCancellable?
  @ObservationIgnored private var cancellables = Set<AnyCancellable>()

  /// Read and written on the main queue only, where the progress and pause events arrive.
  /// Two minutes keeps a listening session to a request pair every two minutes per book,
  /// far below Hardcover's rate limit
  @ObservationIgnored private var progressSchedule = HardcoverProgressSchedule(interval: 120)

  /// Bumped whenever the cached account is cleared, so a `me` lookup that started for the previous
  /// credentials doesn't cache their account after an unlink, a sign-in or a key change
  private let connectedUserGeneration = OSAllocatedUnfairLock(initialState: 0)

  private var readingThreshold: Double {
    UserDefaults.sharedDefaults.object(forKey: Constants.UserDefaults.hardcoverReadingThreshold) as? Double ?? 1.0
  }

  private var autoMatchEnabled: Bool {
    UserDefaults.sharedDefaults.bool(forKey: Constants.UserDefaults.hardcoverAutoMatch)
  }

  private var autoAddWantToReadEnabled: Bool {
    UserDefaults.sharedDefaults.bool(forKey: Constants.UserDefaults.hardcoverAutoAddWantToRead)
  }

  init() {}

  func setup(
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol,
    keychain: KeychainServiceProtocol = KeychainService(),
    audioMetadataService: AudioMetadataServiceProtocol = AudioMetadataService(),
    graphQLSession: URLSession = .shared
  ) {
    self.graphQL = GraphQLClient(baseURL: "https://api.hardcover.app/v1/graphql", session: graphQLSession)
    self.libraryService = libraryService
    self.syncService = syncService
    self.keychain = keychain
    self.oauthSession = HardcoverOAuthSession(keychain: keychain)
    self.audioMetadataService = audioMetadataService

    bindKeychainObserver()
  }

  /// The bare API key; tokens saved with their `Bearer ` prefix (before Hardcover's API keys) read without it
  var authorization: String? {
    get {
      guard let storedToken = try? keychain.get(.hardcoverToken) else { return nil }

      let apiKey = Self.apiKey(from: storedToken)
      return apiKey.isEmpty ? nil : apiKey
    }
    set {
      let apiKey = newValue.map(Self.apiKey(from:)) ?? ""

      /// Saving the settings writes the key back unchanged: that's not another account
      guard apiKey != (authorization ?? "") else { return }

      clearConnectedUser()

      if !apiKey.isEmpty {
        try? self.keychain.set(apiKey, key: .hardcoverToken)
      } else {
        try? self.keychain.remove(.hardcoverToken)
      }
    }
  }

  var isConnected: Bool {
    isSignedInWithOAuth || authorization != nil
  }

  var isSignedInWithOAuth: Bool {
    oauthSession.isSignedIn
  }

  var connectedUsername: String? {
    UserDefaults.sharedDefaults.string(forKey: Constants.UserDefaults.hardcoverUsername)
  }

  var needsSignInAgain: Bool {
    oauthSession.tokens?.missingScopes.isEmpty == false
  }

  /// The connected account's Hardcover user id, written as `hostId` on the links it makes.
  /// One account can be connected today; the id lets a later version tell accounts apart
  private var connectedUserId: String? {
    UserDefaults.sharedDefaults.string(forKey: Constants.UserDefaults.hardcoverUserId)
  }

  /// The API key in what the user entered: trimmed, without a leading `Bearer` (copied from older tokens)
  static func apiKey(from input: String) -> String {
    let token = input.trimmingCharacters(in: .whitespacesAndNewlines)

    guard
      let scheme = token.range(of: #"^bearer(\s+|$)"#, options: [.regularExpression, .caseInsensitive])
    else { return token }

    return String(token[scheme.upperBound...])
  }
}

extension HardcoverService {
  func getBooks(for item: SimpleLibraryItem, perPage: Int) async throws -> BooksData {
    let searchQuery = await buildSearchQuery(for: item)
    Self.logger.info("Using search query for '\(item.title)': '\(searchQuery)'")

    return try await searchBooks(query: searchQuery, perPage: perPage)
  }

  func searchBooks(query: String, perPage: Int) async throws -> BooksData {
    Self.logger.info("Using custom search query: '\(query)'")

    let queryString = """
        query GetBooks($query: String!, $per_page: Int!) {
          search(
            query: $query
            query_type: "book"
            per_page: $per_page
            page: 1
          ) {
            results
          }
        }
        """

    let result = try await execute(
      query: queryString,
      variables: [
        "query": query,
        "per_page": perPage,
      ],
      responseType: BooksData.self
    )

    return result
  }

  func getBook(id: Int) async throws -> SimpleHardcoverBook? {
    Self.logger.info("Fetching Hardcover book info for id \(id)")

    let queryString = """
        query GetBook($id: Int!) {
          books(where: {id: {_eq: $id}}, limit: 1) {
            id
            title
            image { url }
            contributions { author { name } }
          }
        }
        """

    let result = try await execute(
      query: queryString,
      variables: ["id": id],
      responseType: BookByIdData.self
    )

    guard let book = result.books.first else { return nil }

    return SimpleHardcoverBook(
      id: book.id,
      artworkURL: book.image?.url.flatMap(URL.init(string:)),
      title: book.title,
      author: book.contributions?.first?.author?.name ?? "",
      status: .local
    )
  }

  private func insertUserBook(bookID: Int, status: HardcoverBook.Status) async throws -> InsertUserBookData {
    let mutation = """
        mutation InsertUserBook($book_id: Int!, $status_id: Int!) {
          insert_user_book(
            object: {book_id: $book_id, status_id: $status_id}
          ) {
            id
          }
        }
        """

    return try await execute(
      query: mutation,
      variables: [
        "book_id": bookID,
        "status_id": Int(status.rawValue),
      ],
      responseType: InsertUserBookData.self
    )
  }

  private func deleteUserBook(userBookID: Int) async throws -> DeleteUserBookData {
    let mutation = """
        mutation DeleteUserBook($id: Int!) {
          delete_user_book(id: $id) {
            book_id
          }
        }
        """

    return try await execute(
      query: mutation,
      variables: [
        "id": userBookID
      ],
      responseType: DeleteUserBookData.self
    )
  }
}

extension HardcoverService {
  /// OAuth first, else the API key. Hardcover's API requires the `Bearer` scheme, which its API keys
  /// (`hc_pat_…`) no longer include. A signed-in token the API refuses is refreshed once and the
  /// request sent again: it lasts a week, so a refusal means it was revoked or the clock was off
  private func execute<T: Codable>(
    query: String,
    variables: [String: Any]? = nil,
    responseType: T.Type
  ) async throws -> T {
    let oauthToken = try await oauthSession.accessToken()
    let token = oauthToken ?? authorization

    do {
      return try await graphQL.execute(
        query: query,
        variables: variables,
        authorization: token.map { "Bearer \($0)" },
        responseType: responseType
      )
    } catch GraphQLClient.Error.httpError(401) where oauthToken != nil {
      let refreshed = try await oauthSession.accessToken(replacing: oauthToken)

      return try await graphQL.execute(
        query: query,
        variables: variables,
        authorization: refreshed.map { "Bearer \($0)" },
        responseType: responseType
      )
    }
  }

  func signIn(authenticate: (URL) async throws -> URL) async throws {
    let attempt = HardcoverOAuth.makeAuthorization()
    let redirect = try await authenticate(attempt.url)
    let code = try HardcoverOAuth.authorizationCode(from: redirect, for: attempt)

    try await oauthSession.signIn(code: code, codeVerifier: attempt.codeVerifier)
    clearConnectedUser()
    /// One account at a time: the sign-in replaces an API key
    authorization = nil

    Self.logger.info("Signed in to Hardcover")
    _ = await fetchConnectedUserId()
  }

  func disconnect() async {
    authorization = nil
    await oauthSession.signOut()
    clearConnectedUser()
    Self.logger.info("Disconnected from Hardcover")
  }

  /// The connected account's user id, read from `me` the first time it's needed: after signing in,
  /// after an API key is saved, or for an API key saved before ids were stored. Nil when offline
  func fetchConnectedUserId() async -> String? {
    if let connectedUserId { return connectedUserId }

    guard isConnected else { return nil }

    let generation = connectedUserGeneration.withLock { $0 }

    do {
      let result = try await execute(
        query: "query Me { me { id username } }",
        responseType: MeData.self
      )

      guard let user = result.me.first else { return nil }

      let userId = String(user.id)
      /// Under the lock, so a clear can't land between the check and the write
      let isCurrent = connectedUserGeneration.withLock { current in
        guard current == generation else { return false }

        UserDefaults.sharedDefaults.set(userId, forKey: Constants.UserDefaults.hardcoverUserId)
        UserDefaults.sharedDefaults.set(user.username, forKey: Constants.UserDefaults.hardcoverUsername)
        return true
      }

      guard isCurrent else {
        Self.logger.info("Dropped a Hardcover account lookup made for credentials since replaced")
        return nil
      }

      return userId
    } catch {
      Self.logger.error("Failed to read the connected Hardcover account: \(error)")
      return nil
    }
  }

  private func clearConnectedUser() {
    connectedUserGeneration.withLock { generation in
      generation += 1
      UserDefaults.sharedDefaults.removeObject(forKey: Constants.UserDefaults.hardcoverUserId)
      UserDefaults.sharedDefaults.removeObject(forKey: Constants.UserDefaults.hardcoverUsername)
    }
  }

  /// Both ways of connecting post here; whether one is left decides, not which changed.
  /// A sign-in that replaces an API key posts its set before the key's removal.
  /// The Keychain posts on the writer's thread, often the OAuth session's actor: handled on main,
  /// where the subscriptions are changed
  private func bindKeychainObserver() {
    keychain.valueUpdatedPublisher
      .filter { $0.key == .hardcoverToken || $0.key == .hardcoverSession }
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.credentialsChanged()
      }
      .store(in: &cancellables)

    credentialsChanged()
  }

  private func credentialsChanged() {
    guard isConnected else {
      stopTrackingLibraryUpdates()
      return
    }

    startTrackingLibraryUpdates()

    guard connectedUserId == nil else { return }

    Task { [weak self] in
      _ = await self?.fetchConnectedUserId()
    }
  }

  private func stopTrackingLibraryUpdates() {
    guard progressSubscription != nil else { return }

    Self.logger.info("Stopping library updates for Hardcover sync")

    metadataSubscription?.cancel()
    progressSubscription?.cancel()
    pauseSubscription?.cancel()
    metadataSubscription = nil
    progressSubscription = nil
    pauseSubscription = nil
  }

  /// Once per connection: a token refresh, or saving the same key, posts again while tracking
  private func startTrackingLibraryUpdates() {
    guard progressSubscription == nil else { return }

    Self.logger.info("Starting to track library updates for Hardcover sync")

    metadataSubscription = libraryService.metadataUpdatePublisher
      .sink { [weak self] metadata in
        guard
          let relativePath = metadata["relativePath"] as? String,
          let isFinished = metadata["isFinished"] as? Bool,
          isFinished == true
        else { return }

        Task { [weak self] in
          guard let self else { return }
          await self.handleBookFinished(relativePath: relativePath)
        }
      }

    progressSubscription = libraryService.progressUpdatePublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] progress in
        guard
          let self,
          let relativePath = progress["relativePath"] as? String,
          let percentCompleted = progress["percentCompleted"] as? Double
        else { return }

        let percentToSend = self.progressSchedule.record(percentCompleted, for: relativePath, at: Date())

        Task { [weak self] in
          guard let self else { return }
          await self.handleBookStarted(relativePath: relativePath, percentCompleted: percentCompleted)
          if let percentToSend {
            await self.updateReadProgress(percentToSend, for: relativePath)
          }
        }
      }

    /// A pause sends what the schedule held back, so stopping mid-interval loses nothing
    pauseSubscription = NotificationCenter.default.publisher(for: .bookPaused)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self else { return }

        let held = self.progressSchedule.flush(at: Date())
        guard !held.isEmpty else { return }

        Task { [weak self] in
          for entry in held {
            await self?.updateReadProgress(entry.percent, for: entry.relativePath)
          }
        }
      }
  }

  private func handleBookStarted(relativePath: String, percentCompleted: Double) async {
    guard percentCompleted > readingThreshold else { return }

    await updateExternalResources(for: relativePath, to: .reading)
  }

  /// Puts the book's progress on its read in progress on Hardcover. Only for a book Currently
  /// Reading there: the status starts the read, so before it there's nothing to put it on.
  /// Errors are logged and dropped, like every Hardcover call: the next update sends it again
  func updateReadProgress(_ percent: Double, for relativePath: String) async {
    /// Finding the read needs `read:library`, which a sign-in from before progress sync lacks:
    /// Hardcover answers 403 until the user signs in again, which Settings offers
    if oauthSession.tokens?.missingScopes.contains("read:library") == true {
      Self.logger.info("Hardcover progress skipped: the sign-in lacks read:library")
      return
    }

    guard
      let book = await libraryService.getHardcoverBook(for: relativePath),
      book.status == .reading,
      let userId = await fetchConnectedUserId().flatMap(Int.init)
    else { return }

    do {
      let result = try await execute(
        query: Self.readInProgressQuery,
        variables: ["user_id": userId, "book_id": book.id],
        responseType: ReadInProgressData.self
      )

      guard
        let userBook = result.userBooks.first,
        userBook.statusId == Int(HardcoverBook.Status.reading.rawValue),
        let read = userBook.userBookReads.first
      else {
        Self.logger.info("Hardcover progress skipped for book \(book.id): no read in progress")
        return
      }

      let fallbacks = [userBook.edition] + (userBook.book?.defaultEditions ?? [])
      let progress: HardcoverReadProgress
      switch HardcoverReadProgress.evaluate(percent: percent, read: read, fallbacks: fallbacks) {
      case .success(let value):
        progress = value
      case .failure(.noLength):
        Self.logger.info(
          "Hardcover progress skipped for book \(book.id): no edition with a length (read, entry, default audio, ebook, print, most read audio, paged): \(([read.edition] + fallbacks).map(Self.describe))"
        )
        return
      case .failure(.notAhead(let current, let value)):
        Self.logger.info("Hardcover progress skipped for book \(book.id): \(value) isn't ahead of \(current)")
        return
      case .failure(.outOfRange):
        return
      }

      let response = try await execute(
        query: Self.updateProgressMutation,
        variables: ["id": read.id, "object": progress.object],
        responseType: UpdateUserBookReadData.self
      )

      if let error = response.updateUserBookRead.error {
        Self.logger.error("Hardcover refused the progress of book \(book.id): \(error)")
      }
    } catch {
      Self.logger.error("Failed to update Hardcover progress for book \(book.id): \(error)")
    }
  }

  private static func describe(_ edition: ReadInProgressData.Edition?) -> String {
    guard let edition else { return "none" }

    return "#\(edition.id) format \(edition.readingFormatId.map(String.init) ?? "?") "
      + "pages \(edition.pages.map(String.init) ?? "-") seconds \(edition.audioSeconds.map(String.init) ?? "-")"
  }

  /// The started read that isn't finished (Hardcover's "Read in Progress"), with the editions
  /// its length can come from; needs `read:library`
  static let readInProgressQuery = """
    query ReadInProgress($user_id: Int!, $book_id: Int!) {
      user_books(where: {user_id: {_eq: $user_id}, book_id: {_eq: $book_id}}) {
        id
        status_id
        edition {
          id
          pages
          audio_seconds
          reading_format_id
        }
        book {
          default_audio_edition {
            id
            pages
            audio_seconds
            reading_format_id
          }
          default_ebook_edition {
            id
            pages
            audio_seconds
            reading_format_id
          }
          default_physical_edition {
            id
            pages
            audio_seconds
            reading_format_id
          }
          audio_editions: editions(
            where: {reading_format_id: {_eq: 2}, audio_seconds: {_gt: 0}},
            order_by: {users_count: desc},
            limit: 1
          ) {
            id
            pages
            audio_seconds
            reading_format_id
          }
          paged_editions: editions(
            where: {pages: {_gt: 0}},
            order_by: {users_count: desc},
            limit: 1
          ) {
            id
            pages
            audio_seconds
            reading_format_id
          }
        }
        user_book_reads(where: {finished_at: {_is_null: true}}, order_by: {id: desc}, limit: 1) {
          id
          progress_pages
          progress_seconds
          edition {
            id
            pages
            audio_seconds
            reading_format_id
          }
        }
      }
    }
    """

  static let updateProgressMutation = """
    mutation UpdateProgress($id: Int!, $object: DatesReadInput!) {
      update_user_book_read(id: $id, object: $object) {
        error
      }
    }
    """

  private func handleBookFinished(relativePath: String) async {
    await updateExternalResources(for: relativePath, to: .read)
  }

  /// Push the new status to the item's Hardcover link(s), if any — reading-status
  /// actions only exist for Hardcover; other providers' progress rides the
  /// externalUpdate queue instead.
  private func updateExternalResources(
    for relativePath: String,
    to status: HardcoverBook.Status
  ) async {
    let resources = await libraryService.getExternalResources(for: relativePath)

    for resource in resources
    where ExternalResource.ProviderName(rawValue: resource.providerName) == .hardcover {
      await updateHardcoverStatus(status, providerId: resource.providerId, for: relativePath)
    }
  }

  /// Push the given status to Hardcover for the book identified by `providerId`,
  /// keeping the local reference in sync. No-op if it already reached `status`.
  private func updateHardcoverStatus(
    _ status: HardcoverBook.Status,
    providerId: String,
    for relativePath: String
  ) async {
    guard let bookID = Int(providerId) else { return }

    let existing = await libraryService.getHardcoverBook(for: relativePath)
    if let existing, existing.status >= status {
      return
    }

    do {
      Self.logger.info("Updating Hardcover API: book \(bookID) to '\(String(describing: status))' status")
      let response = try await insertUserBook(bookID: bookID, status: status)

      var updated = existing ?? SimpleHardcoverBook(
        id: bookID,
        artworkURL: nil,
        title: "",
        author: "",
        status: status
      )
      updated.status = status
      if updated.userBookID == nil {
        updated.userBookID = response.insertUserBook.id
      }
      await libraryService.setHardcoverBook(updated, for: relativePath)
      Self.logger.info("Updated local Hardcover status to '\(String(describing: status))' for \(relativePath)")
    } catch {
      Self.logger.error("Failed to update Hardcover status for book \(bookID): \(error)")
    }
  }

  func processAutoMatch(for items: [SimpleLibraryItem]) async {
    guard isConnected, autoMatchEnabled, !items.isEmpty else { return }

    Self.logger.info("Auto-matching \(items.count) new items with Hardcover")

    var potentialMatches: [(item: SimpleLibraryItem, book: SimpleHardcoverBook)] = []

    for item in items {
      do {
        let results = try await getBooks(for: item, perPage: 1)

        guard let firstMatch = results.search.results.hits.first?.document else {
          Self.logger.info("No Hardcover match found for '\(item.title)'")
          continue
        }

        let status: HardcoverBook.Status = autoAddWantToReadEnabled ? .library : .local
        let hardcoverBook = SimpleHardcoverBook(from: firstMatch, status: status)
        potentialMatches.append((item: item, book: hardcoverBook))
        Self.logger.info("Found potential match for '\(item.title)': Hardcover ID \(firstMatch.id)")
      } catch {
        Self.logger.error("Failed to search for item '\(item.title)': \(error)")
      }
    }

    var processedCount = 0

    while !potentialMatches.isEmpty {
      let match = potentialMatches.removeFirst()
      let bookID = match.book.id

      if potentialMatches.contains(where: { $0.book.id == bookID }) {
        potentialMatches.removeAll { $0.book.id == bookID }
        Self.logger.info("Detected duplicate matches for Hardcover ID \(bookID) - skipping these matches to prevent incorrect associations")
        continue
      }

      do {
        var book = match.book

        if autoAddWantToReadEnabled {
          let response = try await insertUserBook(
            bookID: bookID,
            status: .library
          )
          book.userBookID = response.insertUserBook.id
          Self.logger.info("Added '\(match.item.title)' to Hardcover Want to Read list")
        }

        await libraryService.setHardcoverBook(book, for: match.item.relativePath)
        await uploadExternalResource(for: book, to: match.item)
        await downloadArtworkIfNeeded(for: book, to: match.item)
        Self.logger.info("Auto-matched '\(match.item.title)' to Hardcover ID \(bookID)")
        processedCount += 1
      } catch {
        Self.logger.error("Failed to auto-match item '\(match.item.title)': \(error)")
      }
    }

    if processedCount != items.count {
      Self.logger.info("Auto-matched \(processedCount) items, skipped \(items.count - processedCount) due to missing or duplicate matches")
    } else {
      Self.logger.info("Auto-matched \(processedCount) items")
    }
  }

  func assignItem(
    _ book: SimpleHardcoverBook?,
    to item: SimpleLibraryItem
  ) async {
    /// Remove any existing hardcover resource first (handles both unlink and swap)
    await deleteExternalResource(for: item)

    guard let book else {
      await libraryService.setHardcoverBook(nil, for: item.relativePath)
      Self.logger.info("Removed Hardcover assignment from '\(item.title)'")
      return
    }

    Self.logger.info("Assigning Hardcover book \(book.id) to '\(item.title)'")

    if autoAddWantToReadEnabled, isConnected {
      do {
        let response = try await insertUserBook(
          bookID: book.id,
          status: .library
        )
        Self.logger.info("Added '\(item.title)' to Hardcover Want to Read list")

        var updated = book
        updated.status = .library
        updated.userBookID = response.insertUserBook.id
        await libraryService.setHardcoverBook(updated, for: item.relativePath)
      } catch {
        Self.logger.error("Failed to add '\(item.title)' to Hardcover Want to Read: \(error)")
        await libraryService.setHardcoverBook(book, for: item.relativePath)
      }
    } else {
      await libraryService.setHardcoverBook(book, for: item.relativePath)
    }

    await uploadExternalResource(for: book, to: item)
    await downloadArtworkIfNeeded(for: book, to: item)
  }

  /// Create the hardcover external resource for the item and sync-upload it if a sync service is available.
  private func uploadExternalResource(
    for book: SimpleHardcoverBook,
    to item: SimpleLibraryItem
  ) async {
    /// Best effort: offline, the link is made without its account
    let hostId = await fetchConnectedUserId()

    guard
      let syncable = await libraryService.setExternalResource(
        providerName: ExternalResource.ProviderName.hardcover.rawValue,
        providerId: String(book.id),
        hostId: hostId,
        for: item.uuid
      )
    else { return }

    syncService.scheduleExternalResourceUpload(
      syncable,
      relativePath: item.relativePath,
      uuid: item.uuid
    )
  }

  /// Delete the hardcover external resource for the item and schedule a delete sync task if a sync service is available.
  private func deleteExternalResource(for item: SimpleLibraryItem) async {
    let providerName = ExternalResource.ProviderName.hardcover.rawValue

    guard
      let providerId = await libraryService.removeExternalResource(
        providerName: providerName,
        for: item.uuid
      )
    else { return }

    syncService.scheduleExternalResourceDeletion(
      providerName: providerName,
      providerId: providerId,
      relativePath: item.relativePath,
      uuid: item.uuid
    )
  }

  /// If the Hardcover book has artwork and the item has none, download it, set it as the
  /// item's artwork, and run the artwork-upload process (which itself no-ops unless cloud
  /// sync is active, i.e. the user is Pro/Lite).
  private func downloadArtworkIfNeeded(
    for book: SimpleHardcoverBook,
    to item: SimpleLibraryItem
  ) async {
    guard
      let artworkURL = book.artworkURL,
      item.artworkURL == nil
    else { return }

    // item.artworkURL == nil can't see EMBEDDED artwork (it only tracks custom/remote),
    // and the cache is populated lazily on first render — so a bare isCached check
    // raced auto-match on import: a not-yet-rendered item's embedded art lost to the
    // Hardcover cover PERMANENTLY (the cache key shadows the extractor forever) and
    // scheduleUploadArtwork then propagated the wrong cover to every device. Run the
    // canonical pipeline first: on a cache miss it extracts embedded artwork; only an
    // item with genuinely no artwork of its own falls back to Hardcover's cover.
    let hasOwnArtwork = await withCheckedContinuation { continuation in
      ArtworkService.retrieveImageFromCache(for: item.relativePath) { result in
        continuation.resume(returning: (try? result.get()) != nil)
      }
    }
    guard !hasOwnArtwork else { return }

    do {
      let (data, response) = try await URLSession.shared.data(from: artworkURL)
      // The cache stores whatever bytes it's given: an error page or a proxy's answer would become
      // the cover, hide the embedded one for good, and be uploaded to every device
      guard let coverData = Self.coverImageData(data, response: response) else {
        Self.logger.error("Hardcover artwork for '\(item.title)' didn't download as an image")
        return
      }
      await ArtworkService.storeInCache(coverData, for: item.relativePath)
      syncService.scheduleUploadArtwork(relativePath: item.relativePath, uuid: item.uuid)
      Self.logger.info("Set Hardcover artwork for '\(item.title)'")
    } catch {
      Self.logger.error("Failed to download Hardcover artwork for '\(item.title)': \(error)")
    }
  }

  /// The downloaded bytes when they're a cover: a 2xx answer that decodes as an image
  static func coverImageData(_ data: Data, response: URLResponse) -> Data? {
    guard
      let status = (response as? HTTPURLResponse)?.statusCode,
      (200...299).contains(status),
      UIImage(data: data) != nil
    else { return nil }
    return data
  }

  func removeFromLibrary(_ book: SimpleHardcoverBook) async throws {
    guard let userBookID = book.userBookID else {
      Self.logger.error("Cannot remove book \(book.id) from Hardcover library: no userBookID")
      return
    }

    Self.logger.info("Removing book \(book.id) from Hardcover library (userBookID: \(userBookID))")
    _ = try await deleteUserBook(userBookID: userBookID)
    Self.logger.info("Successfully removed book \(book.id) from Hardcover library")
  }
}

extension HardcoverService {
  private func buildSearchQuery(for item: SimpleLibraryItem) async -> String {
    switch item.type {
    case .folder, .bound:
      return await buildQueryForFolder(item)
    case .book:
      return await buildQueryForFile(item)
    }
  }

  private func buildQueryForFile(_ item: SimpleLibraryItem) async -> String {
    if let metadata = await audioMetadataService.extractMetadata(from: item.fileURL) {
      return buildSearchString(title: metadata.title, author: metadata.artist)
    }

    return buildSearchString(title: item.title, author: item.details)
  }

  private func buildQueryForFolder(_ item: SimpleLibraryItem) async -> String {
    do {
      let fileManager = FileManager.default
      let contents = try fileManager.contentsOfDirectory(at: item.fileURL, includingPropertiesForKeys: nil)

      if let firstAudioFile = contents.first, let metadata = await audioMetadataService.extractMetadata(from: firstAudioFile) {
        return buildSearchString(title: metadata.title, author: metadata.artist)
      }
    } catch {
      Self.logger.info("No folder contents to read for \(item.title): \(error)")
    }

    // Nothing on disk to read (a streamed volume, an offloaded folder): its first book carries the
    // author it was imported with. Found by uuid, since the import may have moved it into the
    // folder being browsed; read on the view context's queue, as this runs off main. A folder's
    // own `details` is its file count, never an author.
    let author = await MainActor.run(body: { [libraryService] () -> String? in
      guard let current = libraryService?.getSimpleItem(for: item.uuid) else { return nil }

      return libraryService?.fetchContents(at: current.relativePath, limit: nil, offset: nil)?
        .first { $0.type == .book }?
        .details
    })

    return buildSearchString(title: item.title, author: author ?? "")
  }

  private func buildSearchString(title: String, author: String) -> String {
    var cleaned = title

    let patterns = [
      #"(?i)\b(book|part|chapter|volume|vol\.?)\s+\d+\b"#,
      #"(?i)\b\d+\s*-\s*"#,  // "5 - Title" pattern
      #"(?i)^\d+\.\s*"#,  // "5. Title" pattern
    ]

    for pattern in patterns {
      cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    cleaned = cleaned
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)

    if author.isEmpty {
      return cleaned
    } else {
      return "\(cleaned), \(author)"
    }
  }

}

extension SimpleHardcoverBook {
  fileprivate init(from book: BooksData.SearchResults.SearchResponse.Hit.Book, status: HardcoverBook.Status) {
    self.init(
      id: book.id,
      artworkURL: book.image?.url.flatMap(URL.init(string:)),
      title: book.title,
      author: book.authorNames.first ?? "",
      status: status
    )
  }
}

