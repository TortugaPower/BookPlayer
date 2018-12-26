//
//  PlaylistSelectionViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/7/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Themeable
import UIKit

class PlaylistSelectionViewController: UITableViewController {
    var items: [Playlist]!

    var onPlaylistSelected: ((Playlist) -> Void)?

    override func viewDidLoad() {
        self.title = "Select Playlist"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(self.didTapCancel))

        // Remove the line after the last cell
        self.tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.frame.size.width, height: 1))
        self.tableView.register(UINib(nibName: "BookCellView", bundle: nil), forCellReuseIdentifier: "BookCellView")
        self.edgesForExtendedLayout = .bottom

        setUpTheming()
    }

    @objc func didTapCancel() {
        self.dismiss(animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 86
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // swiftlint:disable force_cast
        let cell = tableView.dequeueReusableCell(withIdentifier: "BookCellView", for: indexPath) as! BookCellView

        let playlist = self.items[indexPath.row]

        cell.artwork = playlist.artwork
        cell.title = playlist.title
        cell.playbackState = .stopped

        cell.subtitle = playlist.info()

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let playlist = self.items[indexPath.row]

        self.dismiss(animated: true) {
            self.onPlaylistSelected?(playlist)
        }
    }
}

extension ItemSelectionViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        self.view.backgroundColor = theme.background
        self.tableView.backgroundColor = theme.background
        self.tableView.separatorColor = theme.secondary.withAlpha(newAlpha: 0.5)
    }
}
