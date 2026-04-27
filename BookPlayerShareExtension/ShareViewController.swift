//
//  ShareViewController.swift
//  BookPlayerShareExtension
//
//  Created by gianni.carlo on 20/11/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import UIKit
import BookPlayerKit
import UniformTypeIdentifiers

@objc(ShareExtensionViewController)
class ShareViewController: UIViewController {
  /// Manual navigation bar
  private lazy var navigationBar: UINavigationBar = {
    let navBar = UINavigationBar()
    navBar.translatesAutoresizingMaskIntoConstraints = false

    let navItem = UINavigationItem(title: "Copy")
    navItem.leftBarButtonItem = closeButton
    navItem.rightBarButtonItem = doneButton

    navBar.setItems([navItem], animated: false)
    return navBar
  }()

  private lazy var closeButton: UIBarButtonItem = {
    let barButton = UIBarButtonItem(
      barButtonSystemItem: .cancel,
      target: self,
      action: #selector(self.didPressCancel)
    )
    barButton.tintColor = defaultTheme.linkColor

    return barButton
  }()

  private lazy var doneButton: UIBarButtonItem = {
    let barButton = UIBarButtonItem(
      barButtonSystemItem: .done,
      target: self,
      action: #selector(self.didPressDone)
    )
    barButton.tintColor = defaultTheme.linkColor

    return barButton
  }()

  private lazy var containerDisclaimerLabel: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    /// won't work if set elsewhere
    view.backgroundColor = defaultTheme.systemBackgroundColor
    return view
  }()

  private lazy var disclaimerLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.textAlignment = .center
    label.numberOfLines = 0
    label.text = "When importing folders, make sure to first download the contents locally, as otherwise the cloud items will not be included in the copied folder"
    /// won't work if set elsewhere
    label.textColor = defaultTheme.secondaryColor
    label.font = Fonts.body
    return label
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

  /// Hard-coded default theme to avoid accessing DB
  private lazy var defaultTheme: SimpleTheme = {
    return SimpleTheme.getDefaultTheme(useDarkVariant: UIScreen.main.traitCollection.userInterfaceStyle == .dark)
  }()

  /// Allowed content types
  let contentType = UTType.url.identifier
  /// Shared folder URL
  let sharedFolder = DataManager.getSharedFilesFolderURL()
  /// In-memory array of shared items
  var sharedItems = [URL]()

  /// File extensions BookPlayer can fetch from a remote `http(s)` URL.
  ///
  /// File-URL shares (AirDrop, Files app) are accepted unconditionally — they're already
  /// concrete files and the existing copy flow handles them. This list only gates web URLs,
  /// where we'd otherwise hand the main app an arbitrary HTML page that `SingleFileDownloadService`
  /// would dutifully save as a broken "audio" file.
  static let supportedRemoteFileExtensions: Set<String> = [
    "mp3", "m4a", "m4b", "aac", "flac", "ogg", "opus", "wav", "wma",
    "aiff", "aif", "caf",
    "mp4", "m4v", "mov",
    "zip"
  ]

  override func viewDidLoad() {
    super.viewDidLoad()

    addSubviews()
    addConstraints()
    handleSharedFiles()
  }

  func addSubviews() {
    view.addSubview(navigationBar)
    view.addSubview(containerDisclaimerLabel)
    containerDisclaimerLabel.addSubview(disclaimerLabel)
    view.addSubview(tableView)
  }

  func addConstraints() {
    let safeLayoutGuide = view.safeAreaLayoutGuide

    NSLayoutConstraint.activate([
      navigationBar.topAnchor.constraint(equalTo: safeLayoutGuide.topAnchor),
      navigationBar.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor),
      navigationBar.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor),

      containerDisclaimerLabel.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
      containerDisclaimerLabel.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor),
      containerDisclaimerLabel.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor),

      disclaimerLabel.topAnchor.constraint(equalTo: containerDisclaimerLabel.topAnchor, constant: 8),
      disclaimerLabel.leadingAnchor.constraint(equalTo: containerDisclaimerLabel.leadingAnchor, constant: 12),
      disclaimerLabel.trailingAnchor.constraint(equalTo: containerDisclaimerLabel.trailingAnchor, constant: -12),
      disclaimerLabel.bottomAnchor.constraint(equalTo: containerDisclaimerLabel.bottomAnchor, constant: -8),

      tableView.topAnchor.constraint(equalTo: containerDisclaimerLabel.bottomAnchor),
      tableView.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: safeLayoutGuide.bottomAnchor),
    ])
  }

  func loadAttachments(_ attachments: [NSItemProvider]) {
    var mutableAttachments = attachments
    guard !mutableAttachments.isEmpty else {
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.tableView.reloadData()
        LoadingUtils.stopLoading(in: self)
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

      if let url = data as? URL,
         ShareViewController.isSupportedShareURL(url)
      {
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

    LoadingUtils.loadAndBlock(in: self)
    loadAttachments(attachments)
  }

  @objc func didPressCancel() {
    extensionContext?.cancelRequest(withError: ShareExtensionError.cancelled)
  }

  @objc func didPressDone() {
    LoadingUtils.loadAndBlock(in: self)
    saveSharedItems(sharedItems)
  }

  func saveSharedItems(_ items: [URL]) {
    /// Share extensions can't launch their host app on current iOS — the responder-chain
    /// `openURL:` trick silently no-ops, and `NSExtensionContext.open` is documented as
    /// Today-widget-only. So instead of trying to hand a URL to the main app, we deposit the
    /// final file into the app group's shared folder ourselves: file URLs are copied (already
    /// concrete on disk), web URLs are downloaded. Either way, BookPlayer's main-app
    /// `DirectoryWatcher` on `getSharedFilesFolderURL()` (see `LibraryRootView`) and
    /// `ImportManager.notifyPendingFiles()` import the file on the next foreground — the
    /// same code path that handles AirDropped audio.
    let fileItems = items.filter { $0.isFileURL }
    let webItems = items.filter { !$0.isFileURL }

    for item in fileItems {
      let destinationURL = sharedFolder.appendingPathComponent(item.lastPathComponent)
      try? FileManager.default.copyItem(at: item, to: destinationURL)
    }

    /// Share extensions in practice receive a single URL at a time (Safari and most apps
    /// share one item per gesture), so downloading the first web URL covers the realistic
    /// case. We hold off on `completeRequest` until the download finishes — a foreground
    /// `URLSession` is bound to the share extension's process lifetime, so completing the
    /// request first would tear the download down mid-flight.
    if let webURL = webItems.first {
      downloadIntoSharedFolder(webURL) { [weak self] in
        self?.completeRequestOnMain()
      }
    } else {
      completeRequestOnMain()
    }
  }

  /// Download a web URL straight into the app group's shared folder, then invoke
  /// `completion` (success or failure) so the caller can dismiss the extension.
  ///
  /// Uses a foreground `URLSession` for v1 — fine for the audio-file sizes typical of
  /// share-sheet senders (single tracks, episodes, chapters in the tens-of-MB range). For
  /// multi-gigabyte single files, switching to a background `URLSession` configured with
  /// `sharedContainerIdentifier` would let the transfer survive the extension dismissing,
  /// at the cost of needing the main-app `AppDelegate` to handle
  /// `application(_:handleEventsForBackgroundURLSession:completionHandler:)`.
  private func downloadIntoSharedFolder(_ url: URL, completion: @escaping () -> Void) {
    let destinationFolder = sharedFolder
    let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
      defer { completion() }

      /// `URLSession.downloadTask` reports success on non-2xx responses too — the temp
      /// file just contains the error body. Reject anything that isn't a 2xx so we don't
      /// move a 404 HTML page into the library named `song.mp3`.
      guard error == nil, let tempURL,
            let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
      else { return }

      /// Prefer the server-suggested filename (Content-Disposition) over the URL's last
      /// path component — yt-dlp-multi etc. set this to the actual track name rather than
      /// the opaque token segment.
      let filename = httpResponse.suggestedFilename ?? url.lastPathComponent
      let destinationURL = destinationFolder.appendingPathComponent(filename)

      /// Replace any existing file of the same name in the shared folder so the import
      /// pipeline doesn't get confused by a stale half-download.
      try? FileManager.default.removeItem(at: destinationURL)
      try? FileManager.default.moveItem(at: tempURL, to: destinationURL)
    }
    task.resume()
  }

  private func completeRequestOnMain() {
    DispatchQueue.main.async { [weak self] in
      self?.extensionContext?.completeRequest(returningItems: nil)
    }
  }

  /// Returns `true` for share items BookPlayer can usefully import.
  ///
  /// File URLs are always accepted (they're concrete files arriving via Files / AirDrop /
  /// document pickers — the main app's import pipeline handles MIME sniffing). Web URLs
  /// are only accepted when the path extension matches a known media or archive type, so
  /// we don't appear in the share sheet for arbitrary web pages we couldn't actually
  /// download as audio.
  static func isSupportedShareURL(_ url: URL) -> Bool {
    if url.isFileURL { return true }
    guard let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https"
    else { return false }
    return Self.supportedRemoteFileExtensions.contains(url.pathExtension.lowercased())
  }

  func applyDefaultThemeColors() {
    view.backgroundColor = defaultTheme.systemBackgroundColor
    tableView.backgroundColor = defaultTheme.systemBackgroundColor
    tableView.separatorColor = defaultTheme.separatorColor

    navigationBar.barTintColor = defaultTheme.systemBackgroundColor
    navigationBar.tintColor = defaultTheme.linkColor
    navigationBar.titleTextAttributes = [
      NSAttributedString.Key.foregroundColor: defaultTheme.primaryColor
    ]
    navigationBar.largeTitleTextAttributes = [
      NSAttributedString.Key.foregroundColor: defaultTheme.primaryColor
    ]
  }
}

extension ShareViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return sharedItems.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let item = sharedItems[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: "ShareCellView", for: indexPath)

    var configuration =  cell.defaultContentConfiguration()
    configuration.text = item.lastPathComponent
    configuration.textProperties.font = Fonts.body
    configuration.textProperties.color = defaultTheme.primaryColor
    let imageName = item.isDirectoryFolder ? "folder" : "waveform"
    configuration.image = UIImage(systemName: imageName)
    configuration.imageProperties.tintColor = defaultTheme.linkColor
    cell.contentConfiguration = configuration
    cell.backgroundColor = defaultTheme.systemBackgroundColor

    return cell
  }
}

extension ShareViewController: UITableViewDelegate {}

enum ShareExtensionError: Error {
  case cancelled
}
