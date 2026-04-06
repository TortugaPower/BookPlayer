//
//  IntegrationConnectionViewModelProtocol.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

enum IntegrationConnectionState {
  case disconnected
  case foundServer
  case connected
}

enum IntegrationViewMode {
  case regular
  case viewDetails
}

@MainActor
protocol IntegrationConnectionViewModelProtocol: ObservableObject {
  associatedtype FormVM: IntegrationConnectionFormViewModelProtocol

  var form: FormVM { get set }
  var viewMode: IntegrationViewMode { get set }
  var connectionState: IntegrationConnectionState { get set }

  func handleConnectAction() async throws
  func handleSignInAction() async throws
  func handleSignOutAction()
}
