//
//  LastPlayedModel.swift
//  BookPlayerWidgetsPhone
//
//  Created by Gianni Carlo on 1/10/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

struct LastPlayedModel {
  let relativePath: String?
  let title: String?
  let isPlaying: Bool
  let theme: SimpleTheme

  init(item: WidgetLibraryItem?, isPlaying: Bool, theme: SimpleTheme) {
    self.relativePath = item?.relativePath
    self.title = item?.title
    self.isPlaying = isPlaying
    self.theme = theme
  }
}
