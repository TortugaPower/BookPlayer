//
//  SyncTask.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 21/1/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct SyncTask: Identifiable {
  public let id: String
  public let relativePath: String
  public let jobType: SyncJobType
  let parameters: [String: Any]

  public init(id: String, relativePath: String, jobType: SyncJobType, parameters: [String: Any]) {
    self.id = id
    self.relativePath = relativePath
    self.jobType = jobType
    self.parameters = parameters
  }
}

public struct SyncTaskReference: Identifiable {
  public let id: String
  public let relativePath: String
  public let jobType: SyncJobType

  public init(id: String, relativePath: String, jobType: SyncJobType) {
    self.id = id
    self.relativePath = relativePath
    self.jobType = jobType
  }
}
