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
  var isActive: Bool = false

  func fetchListContents(at relativePath: String?, shouldSync: Bool) async throws -> ([SyncableItem], SyncableItem?) { return ([], nil) }

  func cancelAllJobs() {}

  func accountUpdated(_ customerInfo: CustomerInfo) {}
}
