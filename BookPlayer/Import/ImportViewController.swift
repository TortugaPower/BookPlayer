//
//  ImportViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/6/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import DirectoryWatcher
import Combine
import Themeable
import UIKit

final class ImportViewController: UIViewController, Storyboarded {
  var viewModel: ImportViewModel!
  @IBOutlet weak var descriptionLabel: UILabel!
  @IBOutlet weak var tableView: UITableView!

  private var disposeBag = Set<AnyCancellable>()
  private var files = [ImportFileItem]()
  private var watchers = [DirectoryWatcher]()

  override func viewDidLoad() {
    super.viewDidLoad()

    setUpTheming()
    self.descriptionLabel.text = "import_warning_description".localized
    self.navigationController?.navigationBar.prefersLargeTitles = true
    self.tableView.tableFooterView = UIView()

    self.bindFilesObserver()
  }

  private func bindFilesObserver() {
    self.viewModel.$files.sink { [weak self] files in
      self?.files = files
      self?.tableView.reloadData()

      self?.navigationItem.rightBarButtonItem?.isEnabled = files.count > 0
    }.store(in: &disposeBag)
  }

  @IBAction func didPressCancel(_ sender: UIBarButtonItem) {
    // clean up current operation
    do {
      try self.viewModel.discardImportOperation()
    } catch {
      self.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.viewModel.dismiss()
  }

  @IBAction func didPressDone(_ sender: UIBarButtonItem) {
    self.viewModel.createOperation()
  }
}

extension ImportViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return files.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    // swiftlint:disable force_cast
    let cell = tableView.dequeueReusableCell(withIdentifier: "ImportTableViewCell", for: indexPath) as! ImportTableViewCell
    // swiftlint:enable force_cast
    let fileItem = self.files[indexPath.row]

    let imageName = fileItem.fileUrl.isDirectoryFolder ? "folder" : "waveform"
    cell.iconImageView.image = UIImage(systemName: imageName)
    cell.filenameLabel.text = fileItem.getFileName()
    cell.countLabel.text = fileItem.subItems > 0
    ? String.localizedStringWithFormat("files_title".localized, fileItem.subItems)
    : ""

    cell.onDeleteTap = { [weak self] in
      do {
        try self?.viewModel.deleteItem(fileItem.fileUrl)
      } catch {
        self?.showAlert("error_title".localized, message: error.localizedDescription)
      }
    }

    return cell
  }
}

extension ImportViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return String.localizedStringWithFormat(
      "files_title".localized, self.viewModel.getTotalItems()
    ).localizedCapitalized
  }
}

extension ImportViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.view.backgroundColor = theme.systemBackgroundColor
    self.tableView.backgroundColor = theme.systemBackgroundColor
    self.tableView.separatorColor = theme.separatorColor
    self.descriptionLabel.textColor = theme.secondaryColor

    self.navigationController?.navigationBar.barTintColor = theme.systemBackgroundColor
    self.navigationController?.navigationBar.tintColor = theme.linkColor
    self.navigationController?.navigationBar.titleTextAttributes = [
      NSAttributedString.Key.foregroundColor: theme.primaryColor
    ]
    self.navigationController?.navigationBar.largeTitleTextAttributes = [
      NSAttributedString.Key.foregroundColor: theme.primaryColor
    ]

    self.overrideUserInterfaceStyle = theme.useDarkVariant
    ? UIUserInterfaceStyle.dark
    : UIUserInterfaceStyle.light
  }
}
