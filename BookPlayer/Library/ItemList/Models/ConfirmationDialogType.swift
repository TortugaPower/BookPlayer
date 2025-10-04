//
//  ConfirmationDialogType.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/10/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

/// Represents all possible confirmation dialog types in ItemListView
enum ConfirmationDialogType: Identifiable {
  case itemOptions
  
  var id: String {
    switch self {
    case .itemOptions:
      return "itemOptions"
    }
  }
}
