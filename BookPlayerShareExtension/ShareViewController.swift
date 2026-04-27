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

  /// Retained URLSession delegate. Held so iOS can deliver the completion to *this*
  /// process if the extension survives long enough — see `kickOffBackgroundDownloads`.
  private var backgroundDownloadCoordinator: BackgroundDownloadCoordinator?

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
    /// File URLs (AirDrop, Files, document picker) are concrete on-disk items: copy them
    /// into the app group's shared folder synchronously where the main app's
    /// `ImportManager` will pick them up on next foreground — same code path AirDropped
    /// audio uses.
    ///
    /// Web URLs are handed to a background `URLSession` keyed by
    /// `Constants.shareExtensionBackgroundSessionIdentifier`, with
    /// `sharedContainerIdentifier` set to the app group. The transfer is owned by iOS's
    /// `nsurlsessiond` daemon, not by this extension's process, so we can immediately call
    /// `completeRequest` and let the share UI dismiss without waiting for the bytes. When
    /// the download finishes, iOS launches the BookPlayer main app (in the background if
    /// needed) and `BackgroundShareDownloadDelegate` moves the temp file into the same
    /// shared folder, where the standard import flow takes over.
    let fileItems = items.filter { $0.isFileURL }
    let webItems = items.filter { !$0.isFileURL }

    for item in fileItems {
      let destinationURL = sharedFolder.appendingPathComponent(item.lastPathComponent)
      try? FileManager.default.copyItem(at: item, to: destinationURL)
    }

    if !webItems.isEmpty {
      kickOffBackgroundDownloads(for: webItems)
    }

    completeRequestOnMain()
  }

  /// Schedules a background `URLSession` download for each shared web URL.
  ///
  /// Two delivery paths cover the lifecycle of the transfer:
  ///
  /// 1. If the extension's process is still alive when the download completes (typical for
  ///    small files that finish in seconds), iOS routes the completion to *this session's*
  ///    `URLSessionDownloadDelegate` — `BackgroundDownloadCoordinator` below — which moves
  ///    the temp file into the app group's shared folder.
  /// 2. If iOS suspends/terminates the extension before the download completes, the
  ///    transfer continues via `nsurlsessiond` and iOS routes completion to the main app
  ///    via `application(_:handleEventsForBackgroundURLSession:completionHandler:)`. Main
  ///    app recreates the same session identifier and `BackgroundShareDownloadDelegate`
  ///    handles the move there.
  ///
  /// We previously created the session with `delegate: nil` assuming iOS would always
  /// route to the main app, but in practice downloads small enough to finish before the
  /// extension dies got their events delivered to a nil delegate and the temp file was
  /// silently discarded. The first path above plugs that gap.
  private func kickOffBackgroundDownloads(for urls: [URL]) {
    let config = URLSessionConfiguration.background(
      withIdentifier: Constants.shareExtensionBackgroundSessionIdentifier
    )
    config.sharedContainerIdentifier = Constants.ApplicationGroupIdentifier
    config.sessionSendsLaunchEvents = true
    config.isDiscretionary = false

    /// Retain the coordinator on the running view controller so its delegate methods can
    /// fire if iOS keeps this process alive past the share-sheet dismissal — typical for
    /// downloads that complete in a few seconds.
    let coordinator = BackgroundDownloadCoordinator()
    self.backgroundDownloadCoordinator = coordinator
    let session = URLSession(configuration: config, delegate: coordinator, delegateQueue: nil)
    for url in urls {
      session.downloadTask(with: url).resume()
    }
    session.finishTasksAndInvalidate()
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

/// `URLSessionDownloadDelegate` for the share extension's background download.
///
/// Used when the extension's process is still alive when iOS finishes the download —
/// typically the case for small files that complete in a few seconds. Without a delegate
/// here, iOS would silently discard the temp file because the alive-extension's session
/// is the active one (iOS only escalates to the main app's matching-identifier session
/// when the extension's process is gone).
///
/// Moves the temp file into the app group's shared folder, where the main app's
/// `ImportManager` picks it up on next foreground.
final class BackgroundDownloadCoordinator: NSObject, URLSessionDownloadDelegate {
  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    /// Reject non-2xx HTTP responses — `URLSession` reports success on a 404 and the temp
    /// file just contains the error body.
    if let httpResponse = downloadTask.response as? HTTPURLResponse,
       !(200..<300).contains(httpResponse.statusCode)
    {
      return
    }

    let originalURL = downloadTask.originalRequest?.url
    let filename =
      downloadTask.response?.suggestedFilename
      ?? originalURL?.lastPathComponent
      ?? "shared-\(UUID().uuidString)"
    let destinationURL = DataManager.getSharedFilesFolderURL().appendingPathComponent(filename)

    /// Replace any same-named stale download from a previous attempt.
    try? FileManager.default.removeItem(at: destinationURL)
    try? FileManager.default.moveItem(at: location, to: destinationURL)
  }
}
