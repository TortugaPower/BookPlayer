//
//  MediaActionsRow.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

enum MediaAction: CaseIterable, Identifiable {
  case speed
  case timer
  case bookmark
  case chapters
  case more
  
  var iconName: String {
    switch self {
    case .speed: return "arrow.2.circlepath.circle"
    case .timer: return "moon.fill"
    case .bookmark: return "bookmark"
    case .chapters: return "list.bullet"
    case .more: return "ellipsis"
    }
  }
  
  var id: Self { self }
}

struct MediaActionsRowView: View {
  var action: ((MediaAction) -> Void)?
  
  var body: some View {
    HStack {
      ForEach(0..<MediaAction.allCases.count, id: \.self) { index in
        BubbleButton(iconName: MediaAction.allCases[index].iconName, action: {
          action?(MediaAction.allCases[index])
        })
        
        if index < MediaAction.allCases.count - 1 {
          Spacer()
        }
      }
    }
    .frame(maxWidth: .infinity)
  }
}

#Preview {
  MediaActionsRowView()
}
