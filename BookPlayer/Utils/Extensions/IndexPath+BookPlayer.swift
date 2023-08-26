//
//  IndexPath+BookPlayer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/22/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

extension IndexPath {
  init(row: Int, section: BPSection) {
    self.init(row: row, section: section.rawValue)
  }

  var sectionValue: BPSection {
    return BPSection(rawValue: self.section) ?? .data
  }
}

enum BPSection: Int, CaseIterable {
  case data,
       add
}
