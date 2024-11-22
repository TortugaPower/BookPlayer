//
//  JellyfinConnectionService.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-20.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import JellyfinAPI

class JellyfinConnectionService: BPLogger {
  private let keychainService: KeychainServiceProtocol
  
  @Published var connection: JellyfinConnectionData?
  
  init(keychainService: KeychainServiceProtocol) {
    self.keychainService = keychainService
    
    self.reloadConnection()
  }
  
  func setConnection(_ data: JellyfinConnectionData, saveToKeychain: Bool) {
    guard Self.isConnectionValid(data) else {
      Self.logger.error("failed to set connection data: \(String(reflecting: data))")
      return
    }
    
    connection = data
    
    if saveToKeychain {
      do {
        try keychainService.set(data, key: .jellyfinConnection)
      } catch {
        // ignore issue saving the connection data, we'll just have to prompt again next time
        Self.logger.warning("failed to save connection data to keychain: \(error)")
      }
    }
  }
  
  func deleteConnection() {
    if let apiClient = createClient() {
      Task {
        try await apiClient.signOut()
        // we don't care if this throws
      }
    }
    
    do {
      try keychainService.remove(.jellyfinConnection)
    } catch {
      // ignore
    }
    
    connection = nil
  }
  
  func createClient() -> JellyfinClient? {
    guard let connection else {
      return nil
    }
    return Self.createClient(for: connection)
  }
  
  static func createClient(for connection: JellyfinConnectionData) -> JellyfinClient? {
    guard isConnectionValid(connection) else {
      Self.logger.warning("Cannot create Jellyfin API client from invalid connection data: \(String(reflecting: connection))")
      return nil
    }
    return createClient(serverUrlString: connection.url.absoluteString, accessToken: connection.accessToken)
  }
  
  static func createClient(serverUrlString: String, accessToken: String? = nil) -> JellyfinClient? {
    let mainBundleInfo = Bundle.main.infoDictionary
    let clientName = mainBundleInfo?[kCFBundleNameKey as String] as? String
    let clientVersion = mainBundleInfo?[kCFBundleVersionKey as String] as? String
    let deviceID = UIDevice.current.identifierForVendor
    guard let url = URL(string: serverUrlString), let clientName, let clientVersion, let deviceID else {
      Self.logger.error("cannot build Jellyfin API client. \(serverUrlString), \(clientName), \(clientVersion), \(String(reflecting: deviceID))")
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
  
  private func reloadConnection() {
    connection = nil
    do {
      if let connection: JellyfinConnectionData = try keychainService.get(.jellyfinConnection),
         Self.isConnectionValid(connection)
      {
        self.connection = connection
      }
    } catch {
    }
  }
  
  private static func isConnectionValid(_ data: JellyfinConnectionData) -> Bool {
    return !data.userID.isEmpty && !data.accessToken.isEmpty
  }
}
