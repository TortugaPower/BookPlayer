//
//  SocketService.swift
//  BookPlayer
//
//  Created by Yamil Nuñez Aguirre on 13/8/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import BookPlayerKit
import SocketIO

public protocol SocketServiceProtocol {
  func connectSocket()
  func disconnectSocket()
  func sendEvent(_ event: SocketEvent, payload: [String: Any])
}

public enum SocketEvent: String {
  case timeUpdate = "track_update"
  case lastPlayedItem = "last_played_item"
}

public class SocketService: SocketServiceProtocol, BPLogger {
  var socket: SocketIOClient?
  var manager: SocketManager?
  let keychain: KeychainServiceProtocol

  public init(keychain: KeychainServiceProtocol = KeychainService()) {
    self.keychain = keychain
    let socketStringURL: String = Bundle.main.configurationValue(for: .socketServerURL)

    /// Fail to initialize socket if it's not configured, as it's not required for regular app functionality
    guard let socketURL = URL(string: socketStringURL) else {
      return
    }

    let isSecureString: String = Bundle.main.configurationValue(for: .isSocketSecure)
    let isSecure = Bool(isSecureString) ?? true
    let socketManager = SocketManager(
      socketURL: socketURL,
      config: [.log(false), .compress, .secure(isSecure)]
    )
    self.manager = socketManager
    self.socket = socketManager.defaultSocket
  }

  public func connectSocket() {
    guard
      let socket,
      socket.status == .notConnected || socket.status == .disconnected,
      let accessToken = try? keychain.getAccessToken()
    else { return }

    setupHandlers()
    socket.connect(withPayload: ["authorization": accessToken])
  }

  public func disconnectSocket() {
    socket?.removeAllHandlers()
    socket?.disconnect()
  }

  func setupHandlers() {
    socket?.on(clientEvent: .connect) { _, _ in
      Self.logger.trace("connected")
    }

    socket?.on(SocketEvent.lastPlayedItem.rawValue) { data, _ in
      guard let lastPlayedItem = data[0] as? SyncableItem else { return }
      /// TODO: handle last played item event
      print("lastPlayedItem: \(lastPlayedItem)")
    }
  }

  public func sendEvent(_ event: SocketEvent, payload: [String: Any]) {
    guard
      let socket,
      socket.status == .connected,
      let jsonSerialize = try? JSONSerialization.data(withJSONObject: payload),
      let jsonString = String(data: jsonSerialize, encoding: .utf8)
    else { return }

    socket.emit(event.rawValue, ["data": jsonString])
  }
}
