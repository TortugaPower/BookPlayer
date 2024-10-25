//
//  JellyfinConnectionFormViewModel.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-25.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Foundation

class JellyfinConnectionFormViewModel: ObservableObject {
  @Published var serverUrl: String = ""
  @Published var serverName: String?
}
