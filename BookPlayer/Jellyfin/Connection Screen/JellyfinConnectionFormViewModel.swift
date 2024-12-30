//
//  JellyfinConnectionFormViewModel.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-25.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation

class JellyfinConnectionFormViewModel: ObservableObject {
  @Published var serverUrl: String = ""
  @Published var serverName: String?
  @Published var username: String = ""
  @Published var password: String = ""
  @Published var rememberMe: Bool = true
}
