//
//  MediaActionsRow.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

enum MediaAction: CaseIterable {
  case speed
  case timer
  case bookmark
  case chapters
  case more
  
  var iconName: String {
    switch self {
      case .speed: return "arrow.2.circlepath.circle"
      case .timer: return "timer"
      case .bookmark: return "bookmark"
      case .chapters: return "book"
      case .more: return "ellipsis"
    }
  }

}

struct MediaActionsRowView: View {
  var action: ((MediaAction) -> Void)?
  
  var body: some View {
    HStack(spacing: 16) {
      ForEach(
        MediaAction.allCases,
        id: \.self
      ) { mediaAction in
        BubbleButton(iconName: mediaAction.iconName, action: {
          action?(mediaAction)
        })
      }
    }
  }
}

#Preview {
    MediaActionsRowView()
}
