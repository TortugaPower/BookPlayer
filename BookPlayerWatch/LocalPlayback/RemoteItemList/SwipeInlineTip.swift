//
//  SwipeInlineTip.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 12/26/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import TipKit

@available(watchOS 10.0, *)
struct SwipeInlineTip: Tip {
  var title: Text {
    Text("Swipe rows to see download options")
  }
}
