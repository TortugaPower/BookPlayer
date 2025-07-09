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
class JellyfinConnectionViewModel: ObservableObject, BPLogger {
  enum ViewMode {
    case regular  // for the "Download from Jellyfin" flow
    case viewDetails  // for the connection details + sign out option from the Settings screen
  }

  enum ConnectionState {
    case disconnected
    case foundServer
    case connected
  }

  let connectionService: JellyfinConnectionService

  var navigation: BPNavigation
  @Published var form: JellyfinConnectionFormViewModel
  @Published var viewMode: ViewMode = .regular
  @Published var connectionState: ConnectionState

  private var disposeBag = Set<AnyCancellable>()

  init(
    connectionService: JellyfinConnectionService,
    navigation: BPNavigation,
    mode: ViewMode = .regular
  ) {
    self.connectionService = connectionService
    self._viewMode = .init(initialValue: mode)
    let form = JellyfinConnectionFormViewModel()

    self.navigation = navigation

    if let data = connectionService.connection {
      form.setValues(from: data)
      self._connectionState = .init(initialValue: .connected)

      Task { @MainActor in
        navigation.path.append(
          JellyfinLibraryLevelData.topLevel(libraryName: form.serverName)
        )
      }
    } else {
      self._connectionState = .init(initialValue: .disconnected)
    }

    self._form = .init(initialValue: form)
  }

  @MainActor
  func handleConnectAction() async throws {
    let serverName = try await connectionService.findServer(at: form.serverUrl)
    connectionState = .foundServer
    form.serverName = serverName
  }

  @MainActor
  func handleSignInAction() async throws {
    do {
      try await connectionService.signIn(
        username: form.username,
        password: form.password,
        serverName: form.serverName
      )

      connectionState = .connected
      navigation.path.append(
        JellyfinLibraryLevelData.topLevel(libraryName: form.serverName)
      )
    } catch APIError.unacceptableStatusCode(let statusCode) {
      switch statusCode {
      case 400...499:
        throw JellyfinError.clientError(code: statusCode).localizedDescription
      default:
        throw JellyfinError.unexpectedResponse(code: statusCode).localizedDescription
      }
    } catch {
      throw error
    }
  }

  @MainActor
  func handleSignOutAction() {
    connectionService.deleteConnection()
    form = JellyfinConnectionFormViewModel()
    connectionState = .disconnected
  }

  @MainActor
  func handleGoToLibraryAction() {
    navigation.path.append(
      JellyfinLibraryLevelData.topLevel(libraryName: form.serverName)
    )
  }
}
