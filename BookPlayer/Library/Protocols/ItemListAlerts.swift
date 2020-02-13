//
//  ItemListAlerts.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/11/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit

protocol ItemListAlerts: ItemListActions {}

extension ItemListAlerts {
    func sortDialog() -> UIAlertController {
        let alert = UIAlertController(title: "sort_files_title".localized, message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "sort_title_button".localized, style: .default, handler: { _ in
            self.sort(by: .metadataTitle)
            self.reloadData()
        }))

        alert.addAction(UIAlertAction(title: "sort_filename_button".localized, style: .default, handler: { _ in
            self.sort(by: .fileName)
            self.reloadData()
        }))

        alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))
        return alert
    }

    func createPlaylistAlert(_ namePlaceholder: String = "new_playlist_button".localized, handler: ((_ title: String) -> Void)?) -> UIAlertController {
        let alert = UIAlertController(title: "create_playlist_title".localized,
                                      message: "create_playlist_description".localized,
                                      preferredStyle: .alert)

        alert.addTextField(configurationHandler: { textfield in
            textfield.text = namePlaceholder
        })

        alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "create_button".localized, style: .default, handler: { _ in
            let title = alert.textFields!.first!.text!

            handler?(title)
        }))

        return alert
    }

    func renameItemAlert(_ item: LibraryItem) -> UIAlertController {
        let alert = UIAlertController(title: "rename_title".localized, message: nil, preferredStyle: .alert)

        alert.addTextField(configurationHandler: { textfield in
            textfield.placeholder = item.title
            textfield.text = item.title
        })

        alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "rename_button".localized, style: .default) { _ in
            if let title = alert.textFields!.first!.text, title != item.title {
                item.title = title

                DataManager.saveContext()
                self.reloadData()
            }
        })

        return alert
    }
}
