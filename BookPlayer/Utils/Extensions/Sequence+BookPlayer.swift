//
//  Sequence+BookPlayer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/11/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import Foundation

extension Sequence where Element: Hashable {
  var frequency: [Element: Int] { reduce(into: [:]) { $0[$1, default: 0] += 1 } }
}
