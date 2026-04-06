//
//  AudiobookShelfConnectionViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import SwiftUI

@MainActor
final class AudiobookShelfConnectionViewModel: IntegrationConnectionViewModelProtocol, BPLogger {
  let connectionService: AudiobookShelfConnectionService

  @Published var form: IntegrationConnectionFormViewModel
  @Published var viewMode: IntegrationViewMode = .regular
  @Published var connectionState: IntegrationConnectionState

  private var disposeBag = Set<AnyCancellable>()

  init(
    connectionService: AudiobookShelfConnectionService,
    mode: IntegrationViewMode = .regular
  ) {
    self.connectionService = connectionService
    self._viewMode = .init(initialValue: mode)
    let form = IntegrationConnectionFormViewModel()

    if let data = connectionService.connection {
      form.setValues(url: data.url.absoluteString, serverName: data.serverName, userName: data.userName)
      self._connectionState = .init(initialValue: .connected)
    } else {
      self._connectionState = .init(initialValue: .disconnected)
    }

    self._form = .init(initialValue: form)
  }

  @MainActor
  func handleConnectAction() async throws {
    let serverName = try await connectionService.pingServer(at: form.serverUrl)
    connectionState = .foundServer
    form.serverName = serverName
  }

  @MainActor
  func handleSignInAction() async throws {
    do {
      try await connectionService.signIn(
        username: form.username,
        password: form.password,
        serverUrl: form.serverUrl,
        serverName: form.serverName
      )

      connectionState = .connected
    } catch let error as IntegrationError {
      throw error
    } catch {
      throw error
    }
  }

  @MainActor
  func handleSignOutAction() {
    connectionService.deleteConnection()
    form = IntegrationConnectionFormViewModel()
    connectionState = .disconnected
  }
}
