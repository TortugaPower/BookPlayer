//
//  AudiobookShelfLibraryLevelData.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

enum AudiobookShelfBrowseCategory: String, CaseIterable, Codable, Hashable {
  case books
  case series
  case collections
  case authors
  case narrators

  var title: String {
    switch self {
    case .books: "Books"
    case .series: "Series"
    case .collections: "Collections"
    case .authors: "Authors"
    case .narrators: "Narrators"
    }
  }
}

enum AudiobookShelfItemFilterGroup: String, Codable, Hashable {
  case authors
  case series
  case narrators
}

struct AudiobookShelfItemFilter: Codable, Hashable {
  let group: AudiobookShelfItemFilterGroup
  let value: String
  let title: String

  var queryValue: String {
    let base64Value = Data(value.utf8).base64EncodedString()
    return "\(group.rawValue).\(base64Value)"
  }
}

enum AudiobookShelfLibraryViewSource: Equatable, Hashable {
  case libraries
  case books(libraryID: String, filter: AudiobookShelfItemFilter?)
  case entities(libraryID: String, category: AudiobookShelfBrowseCategory)
  case collection(id: String)

  var libraryID: String {
    switch self {
    case .libraries: ""
    case .books(let libraryID, _): libraryID
    case .entities(let libraryID, _): libraryID
    case .collection(let id): id
    }
  }
}

enum AudiobookShelfLibraryLevelData: Equatable, Hashable {
  case library(source: AudiobookShelfLibraryViewSource, title: String)
  case details(data: AudiobookShelfLibraryItem)
}
