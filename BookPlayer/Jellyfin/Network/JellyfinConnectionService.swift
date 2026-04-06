//
//  JellyfinConnectionService.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-20.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Get
import JellyfinAPI

@Observable
class JellyfinConnectionService: BPLogger {
  private let keychainService: KeychainServiceProtocol

  var connection: JellyfinConnectionData?
  var client: JellyfinClient?


  init(keychainService: KeychainServiceProtocol = KeychainService()) {
    self.keychainService = keychainService
  }

  func setup() {
    reloadConnection()
  }

  /// Finds and creates the api-client for the specified server
  public func findServer(at absolutePath: String) async throws -> String {
    guard let client = createClient(serverUrlString: absolutePath) else {
      throw IntegrationError.noClient("Jellyfin")
    }

    let publicSystemInfo = try await client.send(Paths.getPublicSystemInfo)

    self.client = client

    return publicSystemInfo.value.serverName ?? ""
  }

  /// Sign into the server using the api-client initialized in ``findServer(at:)``
  public func signIn(
    username: String,
    password: String,
    serverName: String
  ) async throws {
    guard let client else {
      throw IntegrationError.noClient("Jellyfin")
    }

    let result = try await client.signIn(username: username, password: password)

    guard
      let accessToken = result.accessToken,
      let userID = result.user?.id
    else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }

    let data = JellyfinConnectionData(
      url: client.configuration.url,
      serverName: serverName,
      userID: userID,
      userName: username,
      accessToken: accessToken
    )

    try keychainService.set(
      data,
      key: .jellyfinConnection
    )

    self.connection = data
    self.client = client
  }

  func saveSelectedLibrary(id: String?) {
    guard var data = connection else { return }
    data.selectedLibraryId = id
    connection = data
    try? keychainService.set(data, key: .jellyfinConnection)
  }

  func deleteConnection() {
    if let client {
      Task {
        // we don't care if this throws
        try await client.signOut()
      }
    }

    do {
      try keychainService.remove(.jellyfinConnection)
    } catch {
      Self.logger.warning("failed to remove connection data from keychain: \(error)")
    }

    connection = nil
    client = nil
  }

  public func fetchTopLevelItems() async throws -> [JellyfinLibraryItem] {
    guard
      let connection
    else {
      throw IntegrationError.noClient("Jellyfin")
    }

    let parameters = Paths.GetUserViewsParameters(userID: connection.userID)

    let response = try await send(Paths.getUserViews(parameters: parameters))

    try Task.checkCancellation()

    let userViews = (response.value.items ?? [])
      .compactMap { JellyfinLibraryItem(apiItem: $0) }

    return userViews
  }

  public func fetchItems(
    in folderID: String?,
    startIndex: Int?,
    limit: Int?,
    sortBy: JellyfinLayout.SortBy,
    searchTerm: String? = nil,
    recursive: Bool = false
  ) async throws -> (items: [JellyfinLibraryItem], nextStartIndex: Int, maxCountItems: Int) {
    // Require a search term when no folder is scoped, to avoid accidental expensive server-wide fetches
    let effectiveSearchTerm = searchTerm.flatMap { $0.isEmpty ? nil : $0 }
    guard folderID != nil || effectiveSearchTerm != nil else {
      return ([], 0, 0)
    }

    let orderBy: [JellyfinAPI.ItemSortBy]
    let sortOrder: [JellyfinAPI.SortOrder]
    switch sortBy {
      case .recent:
        orderBy = [.dateCreated]
        sortOrder = [.descending]
      case .name:
        orderBy = [.name]
        sortOrder = [.ascending]
      case .smart:
        orderBy = [.isFolder, .sortName]
        sortOrder = [.ascending]
    }

    let isRecursive = recursive || searchTerm != nil || folderID == nil
    let itemTypes: [JellyfinAPI.BaseItemKind] = recursive ? [.audioBook] : [.audioBook, .folder]

    let parameters = Paths.GetItemsParameters(
      startIndex: startIndex,
      limit: limit,
      isRecursive: isRecursive,
      searchTerm: searchTerm,
      sortOrder: sortOrder,
      parentID: folderID,
      fields: [.sortName],
      includeItemTypes: itemTypes,
      sortBy: orderBy,
      imageTypeLimit: 1
    )

    let response = try await send(Paths.getItems(parameters: parameters))
    try Task.checkCancellation()

    let nextStartItemIndex =
      if let startIndex = response.value.startIndex, let numItems = response.value.items?.count {
        startIndex + numItems
      } else {
        -1
      }
    let maxNumItems = response.value.totalRecordCount ?? 0

    let items = (response.value.items ?? [])
      .filter { item in item.id != nil }
      .compactMap { item -> JellyfinLibraryItem? in
        return JellyfinLibraryItem(apiItem: item)
      }

    return (items, nextStartItemIndex, maxNumItems)
  }

  /// Fetch audiobooks filtered by album artist ID.
  public func fetchItemsByArtist(
    artistID: String,
    parentID: String?,
    startIndex: Int?,
    limit: Int?,
    sortBy: JellyfinLayout.SortBy
  ) async throws -> (items: [JellyfinLibraryItem], nextStartIndex: Int, maxCountItems: Int) {
    let orderBy: [JellyfinAPI.ItemSortBy]
    let sortOrder: [JellyfinAPI.SortOrder]
    switch sortBy {
    case .recent:
      orderBy = [.dateCreated]
      sortOrder = [.descending]
    case .name:
      orderBy = [.name]
      sortOrder = [.ascending]
    case .smart:
      orderBy = [.sortName]
      sortOrder = [.ascending]
    }

    let parameters = Paths.GetItemsParameters(
      startIndex: startIndex,
      limit: limit,
      isRecursive: true,
      sortOrder: sortOrder,
      parentID: parentID,
      fields: [.sortName],
      includeItemTypes: [.audioBook],
      sortBy: orderBy,
      imageTypeLimit: 1,
      albumArtistIDs: [artistID]
    )

    let response = try await send(Paths.getItems(parameters: parameters))
    try Task.checkCancellation()

    let nextStartItemIndex =
      if let startIndex = response.value.startIndex, let numItems = response.value.items?.count {
        startIndex + numItems
      } else {
        -1
      }
    let maxNumItems = response.value.totalRecordCount ?? 0

    let items = (response.value.items ?? [])
      .compactMap { JellyfinLibraryItem(apiItem: $0) }

    return (items, nextStartItemIndex, maxNumItems)
  }

  /// Fetch album artists in a library.
  public func fetchAlbumArtists(
    parentID: String?,
    startIndex: Int? = nil,
    limit: Int? = nil,
    searchTerm: String? = nil
  ) async throws -> (items: [JellyfinLibraryItem], total: Int) {
    let parameters = Paths.GetAlbumArtistsParameters(
      startIndex: startIndex,
      limit: limit,
      searchTerm: searchTerm,
      parentID: parentID,
      fields: [.sortName],
      imageTypeLimit: 1,
      sortBy: [.sortName],
      sortOrder: [.ascending]
    )

    let response = try await send(Paths.getAlbumArtists(parameters: parameters))
    try Task.checkCancellation()

    let items = (response.value.items ?? [])
      .compactMap { JellyfinLibraryItem(authorApiItem: $0) }
    let total = response.value.totalRecordCount ?? items.count

    return (items, total)
  }

  /// Fetch narrators by scanning audiobook items for People with "Narrator" role or type.
  /// Jellyfin doesn't have a native "Narrator" person kind, so we extract them from item metadata.
  public func fetchNarrators(
    parentID: String? = nil,
    searchTerm: String? = nil,
    limit: Int? = nil
  ) async throws -> (items: [JellyfinLibraryItem], total: Int) {
    // Fetch all audiobooks with People metadata
    let parameters = Paths.GetItemsParameters(
      isRecursive: true,
      parentID: parentID,
      fields: [.people],
      includeItemTypes: [.audioBook],
      imageTypeLimit: 0
    )

    let response = try await send(Paths.getItems(parameters: parameters))
    try Task.checkCancellation()

    // Extract unique narrators from People arrays
    var seenNames = Set<String>()
    var narratorItems = [JellyfinLibraryItem]()

    for apiItem in response.value.items ?? [] {
      for person in apiItem.people ?? [] {
        guard let name = person.name, !name.isEmpty else { continue }

        let isNarrator =
          person.role?.localizedCaseInsensitiveContains("narrator") == true
          || person.type?.rawValue.localizedCaseInsensitiveContains("narrator") == true

        guard isNarrator, !seenNames.contains(name) else { continue }
        seenNames.insert(name)

        let id = person.id ?? name
        narratorItems.append(
          JellyfinLibraryItem(id: id, name: name, kind: .narrator)
        )
      }
    }

    narratorItems.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    return (narratorItems, narratorItems.count)
  }

  /// Fetch audiobooks by a specific narrator (person name or ID).
  public func fetchItemsByPerson(
    personID: String,
    personName: String?,
    parentID: String?,
    startIndex: Int?,
    limit: Int?,
    sortBy: JellyfinLayout.SortBy
  ) async throws -> (items: [JellyfinLibraryItem], nextStartIndex: Int, maxCountItems: Int) {
    let orderBy: [JellyfinAPI.ItemSortBy]
    let sortOrder: [JellyfinAPI.SortOrder]
    switch sortBy {
    case .recent:
      orderBy = [.dateCreated]
      sortOrder = [.descending]
    case .name:
      orderBy = [.name]
      sortOrder = [.ascending]
    case .smart:
      orderBy = [.sortName]
      sortOrder = [.ascending]
    }

    // Use person name for matching (more reliable for narrators extracted from metadata)
    let parameters = Paths.GetItemsParameters(
      startIndex: startIndex,
      limit: limit,
      isRecursive: true,
      sortOrder: sortOrder,
      parentID: parentID,
      fields: [.sortName],
      includeItemTypes: [.audioBook],
      sortBy: orderBy,
      imageTypeLimit: 1,
      person: personName ?? personID
    )

    let response = try await send(Paths.getItems(parameters: parameters))
    try Task.checkCancellation()

    let nextStartItemIndex =
      if let startIndex = response.value.startIndex, let numItems = response.value.items?.count {
        startIndex + numItems
      } else {
        -1
      }
    let maxNumItems = response.value.totalRecordCount ?? 0

    let items = (response.value.items ?? [])
      .compactMap { JellyfinLibraryItem(apiItem: $0) }

    return (items, nextStartItemIndex, maxNumItems)
  }

  public func fetchItemDetails(for id: String) async throws -> JellyfinAudiobookDetailsData {
    let response = try await send(Paths.getItem(itemID: id))
    try Task.checkCancellation()

    let itemInfo = response.value
    let artist: String? = itemInfo.albumArtist
    let filePath: String? = itemInfo.mediaSources?.first?.path ?? itemInfo.path
    let fileSize: Int? = itemInfo.mediaSources?.first?.size
    let runtimeInSeconds: TimeInterval? =
      (itemInfo.runTimeTicks != nil) ? TimeInterval(itemInfo.runTimeTicks!) / 10000000.0 : nil

    return JellyfinAudiobookDetailsData(
      artist: artist,
      filePath: filePath,
      fileSize: fileSize,
      overview: itemInfo.overview,
      runtimeInSeconds: runtimeInSeconds,
      genres: itemInfo.genres,
      tags: itemInfo.tags
    )
  }

  public func fetchAudiobookDownloadURLs(for folderID: String) async throws -> [URL] {
    let parameters = Paths.GetItemsParameters(
      isRecursive: false,
      parentID: folderID,
      includeItemTypes: [.audioBook]
    )

    let response = try await send(Paths.getItems(parameters: parameters))
    try Task.checkCancellation()

    let audiobooks = (response.value.items ?? [])
      .filter { item in item.id != nil }
      .compactMap { item -> JellyfinLibraryItem? in
        return JellyfinLibraryItem(apiItem: item)
      }

    let downloadURLs = audiobooks.compactMap { audiobook in
      do {
        return try createItemDownloadUrl(audiobook)
      } catch {
        Self.logger.warning("Failed to create download URL for audiobook \(audiobook.id): \(error)")
        return nil
      }
    }

    return downloadURLs
  }

  private func send<T>(
    _ request: Request<T>
  ) async throws -> Response<T> where T: Decodable {
    guard let client else {
      throw IntegrationError.noClient("Jellyfin")
    }

    return try await client.send(request)
  }

  private func reloadConnection() {
    guard
      let storedConnection: JellyfinConnectionData = try? keychainService.get(.jellyfinConnection),
      isConnectionValid(storedConnection)
    else {
      Self.logger.warning("failed to load connection data from keychain")
      return
    }

    client = createClient(
      serverUrlString: storedConnection.url.absoluteString,
      accessToken: storedConnection.accessToken
    )
    connection = storedConnection
  }

  private func isConnectionValid(_ data: JellyfinConnectionData) -> Bool {
    return !data.userID.isEmpty && !data.accessToken.isEmpty
  }

  private func createClient(serverUrlString: String, accessToken: String? = nil) -> JellyfinClient? {
    let mainBundleInfo = Bundle.main.infoDictionary
    let clientName = mainBundleInfo?[kCFBundleNameKey as String] as? String
    let clientVersion = mainBundleInfo?[kCFBundleVersionKey as String] as? String
    let deviceID = UIDevice.current.identifierForVendor
    guard let url = URL(string: serverUrlString), let clientName, let clientVersion, let deviceID else {
      Self.logger.error(
        "cannot build Jellyfin API client. \(serverUrlString), \(clientName), \(clientVersion), \(String(reflecting: deviceID))"
      )
      return nil
    }
    let configuration = JellyfinClient.Configuration(
      url: url,
      client: clientName,
      deviceName: UIDevice.current.name,
      deviceID: "\(deviceID.uuidString)-\(clientName)",
      version: clientVersion
    )
    return JellyfinClient(configuration: configuration, accessToken: accessToken)
  }

  func createItemDownloadUrl(_ item: JellyfinLibraryItem) throws -> URL {
    guard let client else {
      throw IntegrationError.noClient("Jellyfin")
    }

    let request = Paths.getDownload(itemID: item.id)
    var components = try createUrlComponentsForApiRequest(request)

    var queryItems = components.queryItems ?? []
    queryItems.append(URLQueryItem(name: "api_key", value: client.accessToken))
    components.queryItems = queryItems

    guard let url = components.url else {
      throw IntegrationError.urlFromComponents(components)
    }

    return url
  }

  func createItemImageURL(_ item: JellyfinLibraryItem, size: CGSize?) throws -> URL {
    var parameters = Paths.GetItemImageParameters()

    if let size {
      parameters.fillWidth = Int(size.width)
      parameters.fillHeight = Int(size.height)
    }

    let request = Paths.getItemImage(itemID: item.id, imageType: "Primary", parameters: parameters)
    let components = try createUrlComponentsForApiRequest(request)

    guard let url = components.url else {
      throw IntegrationError.urlFromComponents(components)
    }

    return url
  }

  private func createUrlComponentsForApiRequest<Response>(
    _ request: Request<Response>
  ) throws -> URLComponents {
    guard let client else {
      throw IntegrationError.noClient("Jellyfin")
    }

    guard let requestUrl = request.url else {
      throw IntegrationError.urlMalformed(nil)
    }

    let requestAbsoluteUrl =
      requestUrl.scheme == nil
      ? client.configuration.url.appendingPathComponent(requestUrl.absoluteString)
      : requestUrl

    guard var components = URLComponents(url: requestAbsoluteUrl, resolvingAgainstBaseURL: false) else {
      throw IntegrationError.urlMalformed(requestUrl)
    }

    if let query = request.query, !query.isEmpty {
      components.queryItems = query.map(URLQueryItem.init)
    }

    return components
  }
}
