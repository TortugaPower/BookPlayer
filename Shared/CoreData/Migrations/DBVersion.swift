//
//  DBVersion.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 26/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import CoreData
import Foundation

enum DBVersion: CaseIterable {
  case v1

  func model() -> NSManagedObjectModel {
    let modelURLs = Bundle.main
      .urls(forResourcesWithExtension: "mom", subdirectory: "BookPlayer.momd") ?? []

    let modelName: String
    switch self {
    case .v1:
      modelName = "Audiobook Player"
    }

    let model = modelURLs
      .filter { $0.lastPathComponent == "\(modelName).mom" }
      .first
      .flatMap(NSManagedObjectModel.init)
    return model ?? NSManagedObjectModel()
  }

  func mappingModelName() -> String? {
    // No migrations needed for v1 (fresh start)
    return nil
  }
}

extension DBVersion {
  init?(model: NSManagedObjectModel) {
    var matchedVersion: DBVersion?
    for version in DBVersion.allCases where version.model() == model {
      matchedVersion = version
      break
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
