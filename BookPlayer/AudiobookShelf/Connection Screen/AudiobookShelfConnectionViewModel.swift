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
final class AudiobookShelfConnectionViewModel: ObservableObject, BPLogger {
  enum ViewMode {
    case regular  // for the "Download from AudiobookShelf" flow
    case viewDetails  // for the connection details + sign out option from the Settings screen
  }

  enum ConnectionState {
    case disconnected
    case foundServer
    case connected
  }

  let connectionService: AudiobookShelfConnectionService

  var navigation: BPNavigation
  @Published var form: AudiobookShelfConnectionFormViewModel
  @Published var viewMode: ViewMode = .regular
  @Published var connectionState: ConnectionState

  private var disposeBag = Set<AnyCancellable>()

  init(
    connectionService: AudiobookShelfConnectionService,
    navigation: BPNavigation,
    mode: ViewMode = .regular
  ) {
    self.connectionService = connectionService
    self._viewMode = .init(initialValue: mode)
    let form = AudiobookShelfConnectionFormViewModel()

    self.navigation = navigation

    if let data = connectionService.connection {
      form.setValues(from: data)
      self._connectionState = .init(initialValue: .connected)

      Task { @MainActor in
        navigation.path.append(
          AudiobookShelfLibraryLevelData.topLevel(libraryName: form.serverName)
        )
      }
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
      navigation.path.append(
        AudiobookShelfLibraryLevelData.topLevel(libraryName: form.serverName)
      )
    } catch let error as AudiobookShelfError {
      throw error.localizedDescription
    } catch {
      throw error
    }
  }

  @MainActor
  func handleSignOutAction() {
    connectionService.deleteConnection()
    form = AudiobookShelfConnectionFormViewModel()
    connectionState = .disconnected
  }

  @MainActor
  func handleGoToLibraryAction() {
    navigation.path.append(
      AudiobookShelfLibraryLevelData.topLevel(libraryName: form.serverName)
    )
  }
}
