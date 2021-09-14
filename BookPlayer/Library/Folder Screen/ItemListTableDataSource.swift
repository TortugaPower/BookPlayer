//
//  ItemListTableDataSource.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 13/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit

typealias SectionType = Section
typealias ItemType = SimpleLibraryItem

class ItemListTableDataSource: UITableViewDiffableDataSource<SectionType, ItemType> {
  // MARK: reordering support

  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    return true
  }

  override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
    guard let sourceIdentifier = itemIdentifier(for: sourceIndexPath) else { return }
    guard sourceIndexPath != destinationIndexPath else { return }
    let destinationIdentifier = itemIdentifier(for: destinationIndexPath)

    var snapshot = self.snapshot()

    if let destinationIdentifier = destinationIdentifier {
      if let sourceIndex = snapshot.indexOfItem(sourceIdentifier),
         let destinationIndex = snapshot.indexOfItem(destinationIdentifier) {
        let isAfter = destinationIndex > sourceIndex &&
          snapshot.sectionIdentifier(containingItem: sourceIdentifier) ==
          snapshot.sectionIdentifier(containingItem: destinationIdentifier)
        snapshot.deleteItems([sourceIdentifier])
        if isAfter {
          snapshot.insertItems([sourceIdentifier], afterItem: destinationIdentifier)
        } else {
          snapshot.insertItems([sourceIdentifier], beforeItem: destinationIdentifier)
        }
      }
    } else {
      let destinationSectionIdentifier = snapshot.sectionIdentifiers[destinationIndexPath.section]
      snapshot.deleteItems([sourceIdentifier])
      snapshot.appendItems([sourceIdentifier], toSection: destinationSectionIdentifier)
    }
    apply(snapshot, animatingDifferences: false)
  }

  // MARK: editing support

  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }

  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      if let identifierToDelete = itemIdentifier(for: indexPath) {
        var snapshot = self.snapshot()
        snapshot.deleteItems([identifierToDelete])
        apply(snapshot)
      }
    }
  }
}
