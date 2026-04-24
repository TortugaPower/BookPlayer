//
//  IntegrationDetailsViewModelProtocol.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

public protocol IntegrationDetailsDataProtocol: Hashable, Identifiable {
  var artist: String? { get }
  var filePath: String? { get }
  var overview: String? { get }
  var runtimeString: String { get }
  var fileSizeString: String { get }
  var genres: [String]? { get }
  var tags: [String]? { get }

  // Optional — AudiobookShelf-specific, with defaults
  var narrator: String? { get }
  var seriesEntries: [IntegrationSeriesEntry] { get }
}

extension IntegrationDetailsDataProtocol {
  var narrator: String? { nil }
  var seriesEntries: [IntegrationSeriesEntry] { [] }
}

public struct IntegrationSeriesEntry: Identifiable, Hashable {
  public let id: String
  public let name: String
  let sequence: String?
  
  public init(id: String, name: String, sequence: String?) {
    self.id = id
    self.name = name
    self.sequence = sequence
  }
}

@MainActor
public protocol IntegrationDetailsViewModelProtocol: ObservableObject {
  associatedtype Item: IntegrationLibraryItemProtocol
  associatedtype Details: IntegrationDetailsDataProtocol

  var item: Item { get }
  var details: Details? { get }
  var error: Error? { get set }

  func fetchData()
  func cancelFetchData()
  func beginDownloadAudiobook(_ item: Item) throws
  func virtualImportAudiobook(_ item: Item) throws
  func handleImportAudiobook(_ item: Item) throws
}
