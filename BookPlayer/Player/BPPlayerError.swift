//
//  BPPlayerError.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 3/10/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation

enum BPPlayerError: Error {
  case fileMissing(relativePath: String)
}

extension BPPlayerError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .fileMissing(let relativePath):
      return "file_missing_description".localized + "\n\(relativePath)"
    }
  }
}
