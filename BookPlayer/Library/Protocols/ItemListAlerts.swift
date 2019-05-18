//
//  ItemListAlerts.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/11/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

protocol ItemListAlerts: ItemListActions {}

extension ItemListAlerts {
    func sortDialog() -> UIAlertController {
        let alert = UIAlertController(title: "Sort Files by", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Title", style: .default, handler: { _ in
            self.sort(by: .metadataTitle)
            self.reloadData()
        }))

        alert.addAction(UIAlertAction(title: "Original File Name", style: .default, handler: { _ in
            self.sort(by: .fileName)
            self.reloadData()
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        return alert
    }

    func createPlaylistAlert(_ namePlaceholder: String = "New Playlist", handler: ((_ title: String) -> Void)?) -> UIAlertController {
        let alert = UIAlertController(title: "Create a new playlist",
                                      message: "Files in playlists are automatically played one after the other",
                                      preferredStyle: .alert)

        alert.addTextField(configurationHandler: { textfield in
            textfield.text = namePlaceholder
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { _ in
            let title = alert.textFields!.first!.text!

            handler?(title)
        }))

        return alert
    }

    func renameItemAlert(_ item: LibraryItem) -> UIAlertController {
        let alert = UIAlertController(title: "Rename item", message: nil, preferredStyle: .alert)

        alert.addTextField(configurationHandler: { textfield in
            textfield.placeholder = item.title
            textfield.text = item.title
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Rename", style: .default) { _ in
            if let title = alert.textFields!.first!.text, title != item.title {
                item.title = title

                DataManager.saveContext()
                self.reloadData()
            }
        })

        return alert
    }
}
