import UIKit

class PlaylistViewControllerRowAction: UITableViewRowAction {

    let item: LibraryItem
    let delegate 

    init(item: LibraryItem, parentView: PlaylistViewController) {
        self.item       = item
        self.parentView = parentView
    }

    private func build() {

        // "…" on a button indicates a follow up dialog instead of an immmediate action in macOS and iOS
        var title = "Delete…"

        // Remove the dots if trying to delete an empty playlist
        if let playlist = item as? Playlist {
            title = playlist.hasBooks() ? title: "Delete"
        }

        let deleteAction = UITableViewRowAction(style: .default, title: title) { (_, indexPath) in
            guard let book = self.item as? Book else {
                guard let playlist =  as? Playlist else {
                    return
                }

                parentView.handleDelete(playlist: playlist, indexPath: indexPath)

                return
            }

            parentView.handleDelete(book: book, indexPath: indexPath)
        }

        deleteAction.backgroundColor = .red

        if item is Playlist {

        }

        let exportAction = UITableViewRowAction(style: .normal, title: "Export") { (_, indexPath) in
            guard let book = self.items[indexPath.row] as? Book else {
                return
            }

            let bookProvider = BookActivityItemProvider(book)

            let shareController = UIActivityViewController(activityItems: [bookProvider], applicationActivities: nil)

            shareController.excludedActivityTypes = [.copyToPasteboard]

            self.present(shareController, animated: true, completion: nil)
        }

        let markCompleteAction = UITableViewRowAction(style: .default, title: "Mark\n Complete ") { (_, _) in
            item.isComplete = true
        }

        markCompleteAction.backgroundColor = UIColor(red:0.00, green:0.54, blue:0.37, alpha:1.00)

        return [deleteAction, exportAction, markCompleteAction]
    }

}

class BookViewController: UITableViewRowAction {
    private func build() {
        let renameAction = UITableViewRowAction(style: .normal, title: "Rename") { (_, indexPath) in
            guard let playlist = self.items[indexPath.row] as? Playlist else {
                return
            }

            let alert = UIAlertController(title: "Rename playlist", message: nil, preferredStyle: .alert)

            alert.addTextField(configurationHandler: { (textfield) in
                textfield.placeholder = playlist.title
                textfield.text = playlist.title
            })

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Rename", style: .default) { _ in
                if let title = alert.textFields!.first!.text, title != playlist.title {
                    playlist.title = title

                    DataManager.saveContext()
                    self.tableView.reloadRows(at: [indexPath], with: .none)
                }
            })

            self.present(alert, animated: true, completion: nil)
        }

        let markCompleteAction = UITableViewRowAction(style: .default, title: "Mark\n Complete ", handler: { (_, i_) in
            let alert = UIAlertController(title: "Mark Completed", message: "Are you sure you want to mark the playlist and it's contents complete?", preferredStyle: .actionSheet)
            let ok = UIAlertAction(title: "Ok", style: .default, handler: { (_) in
                guard let playList = item as? Playlist else { return }
                playList.books?.forEach({ (book) in
                    guard let book  = book as? Book else { return }
                    book.isComplete = true
                })
            })
            let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

            alert.addAction(ok)
            alert.addAction(cancel)

            self.present(alert, animated: true, completion: nil)
        })

        return [deleteAction, renameAction, markCompleteAction]
    }
}
