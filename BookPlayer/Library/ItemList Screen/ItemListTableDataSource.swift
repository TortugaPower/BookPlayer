//
//  ItemListTableDataSource.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 13/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Combine
import UIKit

typealias SectionType = Section
typealias ItemType = SimpleLibraryItem

class ItemListTableDataSource: UITableViewDiffableDataSource<SectionType, ItemType> {
  var reorderUpdates = PassthroughSubject<(item: ItemType, sourceIndexPath: IndexPath, destinationIndexPath: IndexPath), Never>()

  // MARK: reordering support

  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    return indexPath.sectionValue == .data
  }

  override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
    guard sourceIndexPath.sectionValue == .data,
          destinationIndexPath.sectionValue == .data,
          sourceIndexPath.row != destinationIndexPath.row,
          let sourceIdentifier = itemIdentifier(for: sourceIndexPath) else {
        return
    }

    self.reorderUpdates.send((sourceIdentifier, sourceIndexPath, destinationIndexPath))
  }

  // MARK: editing support

  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return indexPath.sectionValue == .data
  }
}
