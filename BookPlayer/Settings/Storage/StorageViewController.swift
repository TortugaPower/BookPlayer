//
//  StorageViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/8/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

struct StorageItem {
  let title: String
  let path: String
  let size: String
}

class StorageViewController: UIViewController {
  @IBOutlet weak var storageSpaceLabel: UILabel!
  @IBOutlet weak var tableView: UITableView!

  @IBOutlet var titleLabels: [UILabel]!
  @IBOutlet var containerViews: [UIView]!
  @IBOutlet var separatorViews: [UIView]!

  var items = [StorageItem]()

  override func viewDidLoad() {
    super.viewDidLoad()

    self.tableView.tableFooterView = UIView()

    self.storageSpaceLabel.text = DataManager.sizeOfItem(at: DataManager.getProcessedFolderURL())

    setUpTheming()
  }
}

extension StorageViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return items.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    // swiftlint:disable force_cast
    let cell = tableView.dequeueReusableCell(withIdentifier: "StorageTableViewCell", for: indexPath) as! StorageTableViewCell

    return cell
  }
}

extension StorageViewController: UITableViewDelegate {

}

extension StorageViewController: Themeable {
  func applyTheme(_ theme: Theme) {
    self.view.backgroundColor = theme.systemGroupedBackgroundColor

    self.tableView.backgroundColor = theme.systemBackgroundColor
    self.tableView.separatorColor = theme.separatorColor

    self.storageSpaceLabel.textColor = theme.secondaryColor

    self.separatorViews.forEach { separatorView in
      separatorView.backgroundColor = theme.separatorColor
    }

    self.containerViews.forEach { view in
      view.backgroundColor = theme.systemBackgroundColor
    }

    self.titleLabels.forEach { label in
      label.textColor = theme.primaryColor
    }
    self.tableView.reloadData()
  }
}
