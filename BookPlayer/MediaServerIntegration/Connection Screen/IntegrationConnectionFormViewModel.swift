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

  func setValues(url: String, serverName: String, userName: String) {
    self.serverUrl = url
    self.serverName = serverName
    self.username = userName
  }
}
