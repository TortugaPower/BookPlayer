//
//  LoadingOverlayState.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 24/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

@Observable
class LoadingOverlayState {
  var show: Bool = false
  var message: String?
  var error: Error?

  init() {}
}
