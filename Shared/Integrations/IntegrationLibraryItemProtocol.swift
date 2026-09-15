//
//  IntegrationLibraryItemProtocol.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

public protocol IntegrationLibraryItemProtocol: Identifiable, Hashable {
  var id: String { get }
  var displayName: String { get }
  /// A playable leaf item rather than a browsable container. The single predicate behind
  /// row selection, select-all and the whole-level bulk actions, so a selection can never
  /// contain something "everything here" would have skipped. Conformers also key artwork
  /// and the disclosure chevron off it.
  var isDownloadable: Bool { get }
  var isNavigable: Bool { get }
  var placeholderImageName: String { get }
}
