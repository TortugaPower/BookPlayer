//
//  IntegrationLibraryItemProtocol.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

protocol IntegrationLibraryItemProtocol: Identifiable, Hashable {
  var id: String { get }
  var displayName: String { get }
  var isDownloadable: Bool { get }
  var isNavigable: Bool { get }
  var placeholderImageName: String { get }
}
