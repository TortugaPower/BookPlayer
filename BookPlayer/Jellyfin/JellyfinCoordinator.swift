//
//  JellyfinCoordinator.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-26.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
import JellyfinAPI
import UIKit

public struct JellyfinConnectionData: Codable {
  public init(url: URL, userID: String, userName: String, accessToken: String) {
    self.url = url
    self.userID = userID
    self.userName = userName
    self.accessToken = accessToken
  }
  
  public let url: URL
  public let userID: String
  public let userName: String
  public let accessToken: String
}

class JellyfinCoordinator: Coordinator {
  let flow: BPCoordinatorPresentationFlow
  private let singleFileDownloadService: SingleFileDownloadService
  private let keychainService: KeychainServiceProtocol
  private var disposeBag = Set<AnyCancellable>()
  
  private var apiClient: JellyfinClient?
  private var userID: String?
  private var libraryName: String?
  
  init(flow: BPCoordinatorPresentationFlow, singleFileDownloadService: SingleFileDownloadService, keychainService: KeychainServiceProtocol) {
    self.flow = flow
    self.singleFileDownloadService = singleFileDownloadService
    self.keychainService = keychainService
    
    bindObservers()
  }
  
  func bindObservers() {
    singleFileDownloadService.eventsPublisher.sink { [weak self] event in
      switch event {
      case .starting(_), .error(_, _, _):
        self?.flow.finishPresentation(animated: true)
      default:
        break
      }
    }
    .store(in: &disposeBag)
  }
  
  private var isLoggedIn: Bool {
    apiClient?.accessToken != nil && userID != nil && !userID!.isEmpty
  }
  
  func start() {
    if !isLoggedIn {
      tryLoginWithSavedConnection()
    }
    
    let vc = if isLoggedIn {
      createJellyfinLibraryScreen(withLibraryName: libraryName ?? "",
                                  userID: userID ?? "",
                                  client: self.apiClient!)
    } else {
      createJellyfinLoginScreen()
    }
    flow.startPresentation(vc, animated: true)
  }
  
  static func createClient(serverUrlString: String, accessToken: String? = nil) -> JellyfinClient? {
    let mainBundleInfo = Bundle.main.infoDictionary
    let clientName = mainBundleInfo?[kCFBundleNameKey as String] as? String
    let clientVersion = mainBundleInfo?[kCFBundleVersionKey as String] as? String
    let deviceID = UIDevice.current.identifierForVendor
    guard let url = URL(string: serverUrlString), let clientName, let clientVersion, let deviceID else {
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
  
  private func tryLoginWithSavedConnection() {
    do {
      guard let data: JellyfinConnectionData = try keychainService.get(.jellyfinConnection) else {
        return
      }
      self.userID = data.userID
      if let apiClient = Self.createClient(serverUrlString: data.url.absoluteString, accessToken: data.accessToken) {
        self.apiClient = apiClient
      }
    } catch {
      // ignore issues retrieving the connection, we'll just have to prompt again and save the new data
    }
  }
  
  private func createJellyfinLoginScreen() -> UIViewController {
    let viewModel = JellyfinConnectionViewModel()
    viewModel.coordinator = self
    viewModel.onTransition = { [viewModel] route in
      switch route {
      case .cancel:
        viewModel.dismiss()
      case .loginFinished(let userID, let client):
        if viewModel.form.rememberMe, let accessToken = client.accessToken {
          let connectionData = JellyfinConnectionData(url: client.configuration.url,
                                                      userID: userID,
                                                      userName: viewModel.form.username,
                                                      accessToken: accessToken)
          do {
            try self.keychainService.set(connectionData, key: .jellyfinConnection)
          } catch {
            // ignore issue saving the connection data, we'll just have to prompt again next time
          }
        }
        
        self.apiClient = client
        self.userID = userID
        self.libraryName = viewModel.form.serverName ?? ""
        let libraryVC = self.createJellyfinLibraryScreen(withLibraryName: self.libraryName!,
                                                         userID: userID,
                                                         client: client)
        self.flow.pushViewController(libraryVC, animated: true)
      }
    }
    
    let vc = JellyfinConnectionViewController(viewModel: viewModel)
    return vc
  }
  
  private func createJellyfinLibraryScreen(withLibraryName libraryName: String, userID: String, client: JellyfinClient) -> UIViewController {
    let viewModel = JellyfinLibraryViewModel(libraryName: libraryName, userID: userID, apiClient: client, singleFileDownloadService: singleFileDownloadService)
    viewModel.coordinator = self

    viewModel.onTransition = { route in
      switch route {
      case .signOut:
        if let apiClientForTask = self.apiClient {
          Task {
            try await apiClientForTask.signOut()
            // we don't care if this throws
          }
        }
        
        do {
          try self.keychainService.remove(.jellyfinConnection)
        } catch {
          // ignore
        }
        
        self.apiClient = nil
        self.userID = nil
        self.libraryName = nil

      case .done:
        break
      }
      viewModel.dismiss()
    }

    let vc = JellyfinLibraryViewController(viewModel: viewModel, apiClient: client)
    return vc
  }
}
