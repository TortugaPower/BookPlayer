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
  func syncListContents(at relativePath: String?) async throws -> ([BookPlayerKit.SyncableItem], BookPlayerKit.SyncableItem?)? {
    return nil
  }

  func syncLibraryContents() async throws -> ([BookPlayerKit.SyncableItem], BookPlayerKit.SyncableItem?) {
    return ([], nil)
  }

  func getRemoteFileURLs(of relativePath: String, type: BookPlayerKit.SimpleItemType) async throws -> [BookPlayerKit.RemoteFileURL] {
    return []
  }

  func downloadRemoteFiles(for relativePath: String, type: BookPlayerKit.SimpleItemType, delegate: URLSessionTaskDelegate) async throws -> [URLSessionDownloadTask] {
    return []
  }

  var isActive: Bool = false

  func fetchListContents(at relativePath: String?, shouldSync: Bool) async throws -> ([SyncableItem], SyncableItem?) { return ([], nil) }

  func cancelAllJobs() {}

  func accountUpdated(_ customerInfo: CustomerInfo) {}

  func getRemoteFileURL(of relativePath: String) async throws -> URL {
    return URL(string: "https://google.com")!
  }

  func downloadRemoteFile(
    for relativePath: String,
    delegate: URLSessionTaskDelegate
  ) async throws -> URLSessionDownloadTask {
    return URLSessionDownloadTask()
  }
}
