//
//  DBVersion.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 26/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import CoreData
import Foundation

enum DBVersion: CaseIterable {
  case v1, v2, v3, v4, v5, v6, v7, v8

  func model() -> NSManagedObjectModel {
    let modelURLs = Bundle.main
      .urls(forResourcesWithExtension: "mom", subdirectory: "BookPlayer.momd") ?? []

    let modelName: String
    switch self {
    case .v1:
      modelName = "Audiobook Player"
    case .v2:
      modelName = "Audiobook Player 2"
    case .v3:
      modelName = "Audiobook Player 3"
    case .v4:
      modelName = "Audiobook Player 4"
    case .v5:
      modelName = "Audiobook Player 5"
    case .v6:
      modelName = "Audiobook Player 6"
    case .v7:
      modelName = "Audiobook Player 7"
    case .v8:
      modelName = "Audiobook Player 8"
    }

    let model = modelURLs
      .filter { $0.lastPathComponent == "\(modelName).mom" }
      .first
      .flatMap(NSManagedObjectModel.init)
    return model ?? NSManagedObjectModel()
  }

  func mappingModelName() -> String? {
    switch self {
    case .v2:
      return "MappingModel_v1_to_v2"
    case .v3:
      return "MappingModel_v2_to_v3"
    case .v4:
      return "MappingModel_v3_to_v4"
    case .v8:
      return "MappingModel_v7_to_v8"
    default:
      return nil
    }
  }
}

extension DBVersion {
  init?(model: NSManagedObjectModel) {
    var matchedVersion: DBVersion?
    for version in DBVersion.allCases {
      if version.model() == model {
        matchedVersion = version
        break
      }
    }

    if let matchedVersion = matchedVersion {
      self = matchedVersion
    } else {
      return nil
    }
  }
}

extension CaseIterable where Self: Equatable {
  func next() -> Self? {
    let all = Self.allCases

    guard let idx = all.firstIndex(of: self) else { return nil }

    let next = all.index(after: idx)

    if next != all.endIndex {
      return all[next]
    } else {
      return nil
    }
  }
}
