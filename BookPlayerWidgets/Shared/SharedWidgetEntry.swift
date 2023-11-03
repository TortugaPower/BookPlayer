//
//  SharedWidgetEntry.swift
//  BookPlayerWidgetsWatch
//
//  Created by Gianni Carlo on 1/11/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation
import WidgetKit

struct SharedWidgetEntry: TimelineEntry {
  /// We don't provide multiple entries, just a single one
  let date = Date()
  let chapterTitle: String
  let bookTitle: String
  let percentCompleted: Double
}
