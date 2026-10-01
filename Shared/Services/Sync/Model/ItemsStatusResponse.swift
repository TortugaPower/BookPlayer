//
//  ItemsStatusResponse.swift
//  BookPlayer
//
//  Created by gianni.carlo on 6/7/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import Foundation

/// `POST /v1/library/status`: each uuid comes back spelled as it was sent
struct ItemsStatusResponse: Decodable {
  /// No row has the uuid, active or deleted: the item needs registering
  let unknown: [String]
  /// An active book whose file isn't in S3
  let unsynced: [String]
}
