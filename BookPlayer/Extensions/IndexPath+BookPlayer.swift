//
//  IndexPath+BookPlayer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/22/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

extension IndexPath {
    init(row: Int, section: Section) {
        self.init(row: row, section: section.rawValue)
    }
    var sectionValue: Section {
        return Section(rawValue: self.section) ?? .library
    }
}

enum Section: Int {
    case library,
    add,
    total
}
