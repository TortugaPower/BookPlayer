//
//  BPNavigation.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/6/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

@MainActor
final class BPNavigation: ObservableObject {
  var dismiss: (() -> Void)?

  @Published var path = NavigationPath()

  nonisolated init() {}
}
