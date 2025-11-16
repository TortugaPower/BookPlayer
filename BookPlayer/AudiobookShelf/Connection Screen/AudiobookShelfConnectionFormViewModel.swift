//
//  AudiobookShelfConnectionFormViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

class AudiobookShelfConnectionFormViewModel: ObservableObject {
  @Published var serverUrl: String = ""
  @Published var serverName: String = ""
  @Published var username: String = ""
  @Published var password: String = ""

  func setValues(from connection: AudiobookShelfConnectionData) {
    serverUrl = connection.url.absoluteString
    serverName = connection.serverName
    username = connection.userName
  }
}
