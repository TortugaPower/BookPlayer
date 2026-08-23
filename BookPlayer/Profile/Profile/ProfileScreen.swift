//
//  ProfileScreen.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 31/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

enum ProfileScreen: Hashable {
  case account
  /// Active queues overview
  case queueTasks
  /// Task list for one queue key
  case queue(String)
}
