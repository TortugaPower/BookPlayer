//
//  Icon.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/19/19.
//  Copyright © 2019 BookPlayer LLC. All rights reserved.
//

import Foundation

struct Icon: Codable, Identifiable {
  var id: String
  var title: String
  private var artist: String?
  var imageName: String
  private var locked: Bool?

  var isLocked: Bool {
    return self.locked ?? false
  }

  var author: String {
    return self.artist ?? "icons_bookplayer_credit_description".localized
  }
}
