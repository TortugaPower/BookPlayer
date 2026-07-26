//
//  IntegrationConnectionFormViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

class IntegrationConnectionFormViewModel: ObservableObject, IntegrationConnectionFormViewModelProtocol {
  @Published var serverUrl: String = ""
  @Published var serverName: String = ""
  @Published var username: String = ""
  @Published var password: String = ""
  @Published var customHeaders: [CustomHeaderEntry] = []

  /// Replaces the whole form. `customHeaders` is deliberately **not** defaulted: it used to default to
  /// `[:]`, and every call site that omitted it silently emptied the form's header list. That is not a
  /// display-only bug — `IntegrationCustomHeadersSectionView` commits on `onDisappear`, so the next
  /// time the sheet closed it wrote that emptiness over the saved connection and the user's headers
  /// were gone on relaunch. Requiring the argument makes the omission a compile error.
  func setValues(
    url: String,
    serverName: String,
    userName: String,
    customHeaders: [String: String]
  ) {
    self.serverUrl = url
    self.serverName = serverName
    self.username = userName
    self.customHeaders = customHeaders
      .sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending })
      .map { CustomHeaderEntry(key: $0.key, value: $0.value) }
  }
}
