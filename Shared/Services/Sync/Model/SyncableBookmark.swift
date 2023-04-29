//
//  SyncableBookmark.swift
//  BookPlayer
//
//  Created by gianni.carlo on 26/4/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation

struct SyncableBookmark: Decodable {
  let key: String
  let time: Double
  let note: String?
}
