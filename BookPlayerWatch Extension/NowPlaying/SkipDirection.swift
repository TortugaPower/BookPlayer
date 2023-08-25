//
//  SkipDirection.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 13/3/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

enum SkipDirection {
  case back, forward
  
  var systemImage: String {
    switch self {
    case .back:
      return "gobackward"
    case .forward:
      return "goforward"
    }
  }
}
