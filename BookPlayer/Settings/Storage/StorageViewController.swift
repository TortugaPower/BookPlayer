//
//  StorageViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/8/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Themeable
import UIKit

final class StorageViewController: UIViewController {
  @IBOutlet weak var filesTitleLabel: LocalizableLabel!
  @IBOutlet weak var storageSpaceLabel: UILabel!
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var loadingViewIndicator: UIActivityIndicatorView!

  @IBOutlet var titleLabels: [UILabel]!
  @IBOutlet var containerViews: [UIView]!
  @IBOutlet var separatorViews: [UIView]!

  private var viewModel = StorageViewModel()
  private var disposeBag = Set<AnyCancellable>()
  private var items = [StorageItem]()

  override func viewDidLoad() {
    super.viewDidLoad()

    self.navigationItem.title = "settings_storage_title".localized

    self.tableView.tableFooterView = UIView()
    self.tableView.isScrollEnabled = true

    self.storageSpaceLabel.text = viewModel.getLibrarySize()

    self.bindItems()

    setUpTheming()
  }

  private func bindItems() {
    self.viewModel.observeFiles()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] storageItems in
        guard !storageItems.isEmpty else { return }

        self?.items = storageItems
        self?.filesTitleLabel.text = "\("files_caps_title".localized) - \(storageItems.count)"
        self?.tableView.reloadData()
        self?.loadingViewIndicator.stopAnimating()
    }.store(in: &disposeBag)
  }
}

extension StorageViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return items.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    // swiftlint:disable force_cast
    let cell = tableView.dequeueReusableCell(withIdentifier: "StorageTableViewCell", for: indexPath) as! StorageTableViewCell
    let item = self.items[indexPath.row]

    cell.titleLabel.text = item.title
    cell.sizeLabel.text = item.formattedSize()
    cell.filenameLabel.text = item.path
    cell.warningButton.isHidden = !item.showWarning

    cell.onWarningTap = {
      self.showAlert(nil, message: "The digital book is missing, link an existing one or create one")
    }

    cell.onDeleteTap = {
      let alert = UIAlertController(title: nil,
                                    message: String(format: "delete_single_item_title".localized, item.title),
                                    preferredStyle: .alert)

      alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

      alert.addAction(UIAlertAction(title: "delete_button".localized, style: .destructive, handler: { _ in
        do {
          try self.viewModel.handleDelete(for: item)
        } catch {
          self.showAlert("error_title".localized, message: error.localizedDescription)
        }
      }))

      self.present(alert, animated: true, completion: nil)
    }

    return cell
  }
}

extension StorageViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return UITableView.automaticDimension
  }
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

    self.overrideUserInterfaceStyle = theme.useDarkVariant
      ? UIUserInterfaceStyle.dark
      : UIUserInterfaceStyle.light
  }
}
