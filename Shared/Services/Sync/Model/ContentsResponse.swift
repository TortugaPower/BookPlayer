//
//  ContentsResponse.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/7/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

struct ContentsResponse: Decodable {
  let content: [SyncableItem]
}
