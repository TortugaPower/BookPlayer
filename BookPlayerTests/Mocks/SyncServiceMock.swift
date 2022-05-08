//
//  SyncServiceMock.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 23/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation
import RevenueCat

class SyncServiceMock: SyncServiceProtocol {
  func syncLibrary() async throws {}

  func accountUpdated(_ customerInfo: CustomerInfo) {}

  func isReachable(_ flag: Bool) {}
}
