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

final class StorageViewController: BaseViewController<StorageCoordinator, StorageViewModel>, Storyboarded {
  @IBOutlet weak var filesTitleLabel: LocalizableLabel!
  @IBOutlet weak var storageSpaceLabel: UILabel!
  @IBOutlet weak var fixAllButton: UIButton!
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var loadingViewIndicator: UIActivityIndicatorView!

  @IBOutlet var titleLabels: [UILabel]!
  @IBOutlet var containerViews: [UIView]!
  @IBOutlet var separatorViews: [UIView]!

  private var disposeBag = Set<AnyCancellable>()
  private var items = [StorageItem]() {
    didSet {
      self.fixAllButton.isHidden = !self.items.contains { $0.showWarning }
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.navigationItem.title = "settings_storage_title".localized
    self.fixAllButton.setTitle("storage_fix_all_title".localized, for: .normal)

    self.tableView.tableFooterView = UIView()
    self.tableView.isScrollEnabled = true

    self.storageSpaceLabel.text = viewModel.getLibrarySize()

    self.bindObservers()

    setUpTheming()
  }

  private func bindObservers() {
    self.viewModel.observeFiles()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] storageItems in
        guard let loadedItems = storageItems else { return }

        self?.items = loadedItems
        self?.filesTitleLabel.text = "\("files_caps_title".localized) - \(loadedItems.count)"
        self?.tableView.reloadData()
        self?.loadingViewIndicator.stopAnimating()
    }.store(in: &disposeBag)

    self.fixAllButton.publisher(for: .touchUpInside)
      .sink { [weak self] _ in
        guard let self = self else { return }

        let brokenItems = self.viewModel.getBrokenItems()

        guard !brokenItems.isEmpty else { return }

        let alert = UIAlertController(title: nil,
                                      message: "storage_fix_files_description".localized,
                                      preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

        alert.addAction(UIAlertAction(title: "storage_fix_file_button".localized, style: .default, handler: { _ in
          self.loadingViewIndicator.startAnimating()
          do {
            try self.viewModel.handleFix(for: brokenItems) {
              self.loadingViewIndicator.stopAnimating()
            }
          } catch {
            self.loadingViewIndicator.stopAnimating()
            self.showAlert("error_title".localized, message: error.localizedDescription)
          }
        }))

        self.present(alert, animated: true, completion: nil)
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

    cell.onWarningTap = { [weak self] in
      let alert = UIAlertController(title: nil,
                                    message: "storage_fix_file_description".localized,
                                    preferredStyle: .alert)

      alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

      alert.addAction(UIAlertAction(title: "storage_fix_file_button".localized, style: .default, handler: { [weak self] _ in
        do {
          try self?.viewModel.handleFix(for: item)
        } catch {
          self?.showAlert("error_title".localized, message: error.localizedDescription)
        }
      }))

      self?.present(alert, animated: true, completion: nil)
    }

    cell.onDeleteTap = { [weak self] in
      let alert = UIAlertController(title: nil,
                                    message: String(format: "delete_single_item_title".localized, item.title),
                                    preferredStyle: .alert)

      alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

      alert.addAction(UIAlertAction(title: "delete_button".localized, style: .destructive, handler: { _ in
        do {
          try self?.viewModel.handleDelete(for: item)
        } catch {
          self?.showAlert("error_title".localized, message: error.localizedDescription)
        }
      }))

      self?.present(alert, animated: true, completion: nil)
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
  func applyTheme(_ theme: SimpleTheme) {
    self.view.backgroundColor = theme.systemGroupedBackgroundColor
    self.fixAllButton.tintColor = theme.linkColor

    self.tableView.backgroundColor = theme.systemBackgroundColor
    self.tableView.separatorColor = theme.separatorColor

    self.storageSpaceLabel.textColor = theme.secondaryColor

    self.separatorViews.forEach { $0.backgroundColor = theme.separatorColor }

    self.containerViews.forEach { $0.backgroundColor = theme.systemBackgroundColor }

    self.titleLabels.forEach { $0.textColor = theme.primaryColor }

    self.tableView.reloadData()

    self.overrideUserInterfaceStyle = theme.useDarkVariant
      ? UIUserInterfaceStyle.dark
      : UIUserInterfaceStyle.light
  }
}
