//
//  SyncService.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Combine
import Foundation
import RevenueCat

public protocol SyncServiceProtocol {
  func accountUpdated(_ customerInfo: CustomerInfo)
  func isReachable(_ flag: Bool)
  func syncLibrary()
}

public final class SyncService: SyncServiceProtocol {
  let client: NetworkClientProtocol
  private let provider: NetworkProvider<LibraryAPI>

  @Published var isActive: Bool = false
  @Published var isReachable: Bool = false

  private var disposeBag = Set<AnyCancellable>()

  public init(client: NetworkClientProtocol = NetworkClient()) {
    self.client = client
    self.provider = NetworkProvider(client: client)
  }

  public func accountUpdated(_ customerInfo: CustomerInfo) {
    self.isActive = !customerInfo.activeSubscriptions.isEmpty
  }

  public func isReachable(_ flag: Bool) {
    self.isReachable = flag

    if flag {
      self.retryQueuedJobs()
    }
  }

  public func syncLibrary() {
    // Request library contents
    // Compare folder structure
    // Create upload jobs if necessary
  }

  public func retryQueuedJobs() {

  }

  public func createJob() {

  }
}
