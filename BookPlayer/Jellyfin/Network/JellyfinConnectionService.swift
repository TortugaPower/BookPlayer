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

class JellyfinConnectionService: BPLogger {
  private let keychainService: KeychainServiceProtocol

  /// TODO: remove published once we remove it from settings
  @Published var connection: JellyfinConnectionData?
  var client: JellyfinClient?

  init(keychainService: KeychainServiceProtocol) {
    self.keychainService = keychainService

    self.reloadConnection()
  }

  /// Finds and creates the api-client for the specified server
  public func findServer(at absolutePath: String) async throws -> String {
    guard let client = createClient(serverUrlString: absolutePath) else {
      throw JellyfinError.noClient
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
      fatalError("Client not initialized when attempting to sign in")
    }

    let result = try await client.signIn(username: username, password: password)

    guard
      let accessToken = result.accessToken,
      let userID = result.user?.id
    else {
      throw JellyfinError.unexpectedResponse(code: nil).localizedDescription
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

  public func send<T>(
    _ request: Request<T>
  ) async throws -> Response<T> where T: Decodable {
    guard let client else {
      throw JellyfinError.noClient
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
      throw JellyfinError.noClient
    }

    let request = Paths.getDownload(itemID: item.id)
    var components = try createUrlComponentsForApiRequest(request)

    var queryItems = components.queryItems ?? []
    queryItems.append(URLQueryItem(name: "api_key", value: client.accessToken))
    components.queryItems = queryItems

    guard let url = components.url else {
      throw JellyfinError.urlFromComponents(components)
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
      throw JellyfinError.urlFromComponents(components)
    }

    return url
  }

  private func createUrlComponentsForApiRequest<Response>(
    _ request: Request<Response>
  ) throws -> URLComponents {
    guard let client else {
      throw JellyfinError.noClient
    }

    guard let requestUrl = request.url else {
      throw JellyfinError.urlMalformed(nil)
    }

    let requestAbsoluteUrl =
      requestUrl.scheme == nil
      ? client.configuration.url.appendingPathComponent(requestUrl.absoluteString)
      : requestUrl

    guard var components = URLComponents(url: requestAbsoluteUrl, resolvingAgainstBaseURL: false) else {
      throw JellyfinError.urlMalformed(requestUrl)
    }

    if let query = request.query, !query.isEmpty {
      components.queryItems = query.map(URLQueryItem.init)
    }

    return components
  }
}
