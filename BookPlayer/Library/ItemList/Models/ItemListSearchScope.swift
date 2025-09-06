//
//  ItemListSearchScope.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

enum ItemListSearchScope: String, CaseIterable, Identifiable {
  var id: Self { self }

  case all, books, folders

  var title: LocalizedStringKey {
    switch self {
    case .all: "All"
    case .books: "books_title"
    case .folders: "folders_title"
    }
  }
}
