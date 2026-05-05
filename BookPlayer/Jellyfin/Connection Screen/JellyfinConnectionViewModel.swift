//
//  JellyfinConnectionViewModel.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-25.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Get
import JellyfinAPI
import SwiftUI

@MainActor
final class JellyfinConnectionViewModel: IntegrationConnectionViewModelProtocol, BPLogger {
  let connectionService: JellyfinConnectionService

  @Published var form: IntegrationConnectionFormViewModel
  @Published var viewMode: IntegrationViewMode = .regular
  @Published var connectionState: IntegrationConnectionState

  private var disposeBag = Set<AnyCancellable>()

  init(
    connectionService: JellyfinConnectionService,
    mode: IntegrationViewMode = .regular
  ) {
    self.connectionService = connectionService
    self._viewMode = .init(initialValue: mode)
    let form = IntegrationConnectionFormViewModel()

    if let data = connectionService.connection {
      form.setValues(
        url: data.url.absoluteString,
        serverName: data.serverName,
        userName: data.userName,
        customHeaders: data.customHeaders
      )
      self._connectionState = .init(initialValue: .connected)
    } else {
      self._connectionState = .init(initialValue: .disconnected)
    }

    self._form = .init(initialValue: form)
  }

  @MainActor
  func handleConnectAction() async throws {
    let serverName = try await connectionService.findServer(
      at: form.serverUrl,
      customHeaders: form.customHeadersDictionary()
    )
    connectionState = .foundServer
    form.serverName = serverName
  }

  @MainActor
  func handleSignInAction() async throws {
    do {
      try await connectionService.signIn(
        username: form.username,
        password: form.password,
        serverName: form.serverName,
        customHeaders: form.customHeadersDictionary()
      )

      connectionState = .connected
    } catch APIError.unacceptableStatusCode(let statusCode) {
      switch statusCode {
      case 400...499:
        throw IntegrationError.clientError(code: statusCode)
      default:
        throw IntegrationError.unexpectedResponse(code: statusCode)
      }
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

  @MainActor
  func handleCustomHeadersUpdate() {
    connectionService.updateCustomHeaders(form.customHeadersDictionary())
  }
}
