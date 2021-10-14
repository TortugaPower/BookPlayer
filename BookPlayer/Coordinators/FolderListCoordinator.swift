//
//  FolderListCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit

class FolderListCoordinator: ItemListCoordinator {
  var folder: Folder

  init(
    navigationController: UINavigationController,
    library: Library,
    folder: Folder,
    playerManager: PlayerManager,
    importManager: ImportManager,
    dataManager: DataManager,
    miniPlayerOffset: CGFloat
  ) {
    self.folder = folder

    super.init(
      navigationController: navigationController,
      library: library,
      miniPlayerOffset: miniPlayerOffset,
      playerManager: playerManager,
      importManager: importManager,
      dataManager: dataManager
    )
  }

  override func start() {
    let vc = ItemListViewController.instantiate(from: .Main)
    let viewModel = FolderListViewModel(folder: self.folder,
                                        library: self.library,
                                        player: self.playerManager,
                                        dataManager: self.dataManager,
                                        theme: ThemeManager.shared.currentTheme)
    viewModel.coordinator = self
    vc.viewModel = viewModel
    self.presentingViewController = vc
    self.navigationController.pushViewController(vc, animated: true)
  }

  override func showOperationCompletedAlert(with items: [LibraryItem], availableFolders: [SimpleLibraryItem]) {
    let alert = UIAlertController(
      title: String.localizedStringWithFormat("import_alert_title".localized, items.count),
      message: nil,
      preferredStyle: .alert)

    alert.addAction(UIAlertAction(title: "current_playlist_title".localized, style: .default, handler: nil))

    alert.addAction(UIAlertAction(title: "library_title".localized, style: .default) { [weak self] _ in
      self?.onAction?(.insertIntoLibrary(items))
    })

    alert.addAction(UIAlertAction(title: "new_playlist_button".localized, style: .default) { [weak self] _ in
      var placeholder = "new_playlist_button".localized

      if let item = items.first {
        placeholder = item.title
      }

      self?.showImportIntoNewFolderAlert(placeholder: placeholder, with: items)
    })

    let existingFolderAction = UIAlertAction(title: "existing_playlist_button".localized, style: .default) { _ in
      let vc = ItemSelectionViewController()
      vc.items = availableFolders

      vc.onItemSelected = { selectedFolder in
        self.onAction?(.importIntoFolder(selectedFolder, items: items))
      }

      let nav = AppNavigationController(rootViewController: vc)
      self.navigationController.present(nav, animated: true, completion: nil)
    }

    existingFolderAction.isEnabled = !availableFolders.isEmpty
    alert.addAction(existingFolderAction)

    self.navigationController.present(alert, animated: true, completion: nil)
  }
}
