//
//  PathUuidPair.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 6/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct PathUuidPair {
  public var relativePath: String
  public var uuid: String
  
  public init(relativePath: String, uuid: String = "") {
    self.relativePath = relativePath
    self.uuid = uuid
  }
}
