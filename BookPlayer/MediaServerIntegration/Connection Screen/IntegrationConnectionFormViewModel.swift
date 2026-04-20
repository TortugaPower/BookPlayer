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

  func setValues(
    url: String,
    serverName: String,
    userName: String,
    customHeaders: [String: String] = [:]
  ) {
    self.serverUrl = url
    self.serverName = serverName
    self.username = userName
    self.customHeaders = customHeaders
      .sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending })
      .map { CustomHeaderEntry(key: $0.key, value: $0.value) }
  }
}
