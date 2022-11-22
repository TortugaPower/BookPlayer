//
//  ShareViewController.swift
//  BookPlayerShareExtension
//
//  Created by gianni.carlo on 20/11/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import UIKit
import BookPlayerKit
import UniformTypeIdentifiers

@objc(ShareExtensionViewController)
class ShareViewController: UIViewController {

  private lazy var navigationBar: UINavigationBar = {
    let navBar = UINavigationBar()
    navBar.translatesAutoresizingMaskIntoConstraints = false

    let navItem = UINavigationItem(title: "Import")
    navItem.leftBarButtonItem = closeButton
    navItem.rightBarButtonItem = doneButton

    navBar.setItems([navItem], animated: false)
    return navBar
  }()

  private lazy var closeButton: UIBarButtonItem = {
    return UIBarButtonItem(
      barButtonSystemItem: .cancel,
      target: self,
      action: #selector(self.didPressCancel)
    )
  }()

  private lazy var doneButton: UIBarButtonItem = {
    return UIBarButtonItem(
      barButtonSystemItem: .done,
      target: self,
      action: #selector(self.didPressDone)
    )
  }()

  private lazy var tableView: UITableView = {
    let tableView = UITableView()
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = UITableView.automaticDimension
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ShareCellView")
    tableView.delegate = self
    tableView.dataSource = self
    return tableView
  }()

  /// Allowed content types
  let contentType = UTType.data.identifier

  var sharedItems = [URL]()

  override func viewDidLoad() {
    super.viewDidLoad()

    addSubviews()
    addConstraints()
    handleSharedFiles()
  }

  func addSubviews() {
    view.addSubview(navigationBar)
    view.addSubview(tableView)
  }

  func addConstraints() {
    let safeLayoutGuide = view.safeAreaLayoutGuide

    NSLayoutConstraint.activate([
      navigationBar.topAnchor.constraint(equalTo: safeLayoutGuide.topAnchor),
      navigationBar.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor),
      navigationBar.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor),
      tableView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
      tableView.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: safeLayoutGuide.bottomAnchor),
    ])
  }

  func loadAttachments(_ attachments: [NSItemProvider]) {
    var mutableAttachments = attachments
    guard !mutableAttachments.isEmpty else {
      DispatchQueue.main.async { [weak self] in
        self?.tableView.reloadData()
      }
      return
    }

    let provider = mutableAttachments.removeFirst()

    guard provider.hasItemConformingToTypeIdentifier(contentType) else {
      return loadAttachments(mutableAttachments)
    }

    provider.loadItem(
      forTypeIdentifier: contentType,
      options: nil
    ) { [weak self, mutableAttachments] (data, error) in
      defer {
        self?.loadAttachments(mutableAttachments)
      }

      guard error == nil else { return }

      if let url = data as? URL {
        self?.sharedItems.append(url)
      }
    }
  }

  func handleSharedFiles() {
    // extracting the path to the URL that is being shared
    guard
      let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
      let attachments = extensionItem.attachments
    else {
      didPressCancel()
      return
    }

    loadAttachments(attachments)
  }

  @objc func didPressCancel() {
    extensionContext?.cancelRequest(withError: ShareExtensionError.cancelled)
  }

  @objc func didPressDone() {
    saveSharedItems(sharedItems)
  }

  func saveSharedItems(_ items: [URL]) {
    var mutableItems = items
    guard !mutableItems.isEmpty else {
      DispatchQueue.main.async { [weak self] in
        self?.extensionContext?.completeRequest(returningItems: nil)
      }
      return
    }

    let item = mutableItems.removeFirst()

    if let data = try? Data(contentsOf: item) {
      let documentsFolder = DataManager.getDocumentsFolderURL()
      try? data.write(to: documentsFolder)
    }

    saveSharedItems(mutableItems)
  }
}

extension ShareViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return sharedItems.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let item = sharedItems[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: "ShareCellView", for: indexPath)
    cell.textLabel?.text = item.lastPathComponent
    return cell
  }
}

extension ShareViewController: UITableViewDelegate {

}

enum ShareExtensionError: Error {
  case cancelled
}
