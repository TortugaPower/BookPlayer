//
//  SearchListViewController.swift
//  BookPlayer
//
//  Created by gianni.carlo on 4/11/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Themeable
import UIKit

class SearchListViewController: BaseViewController<SearchListCoordinator, SearchListViewModel> {

  private var disposeBag = Set<AnyCancellable>()
  /// Width for each scope item
  let scopeItemWidth: CGFloat = 143
  /// Search bar
  private let searchBar = UISearchBar()
  /// Table to display search results
  private lazy var tableView: UITableView = {
    let tableView = UITableView()
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = UITableView.automaticDimension
    tableView.register(UINib(nibName: "BookCellView", bundle: nil), forCellReuseIdentifier: "BookCellView")
    tableView.delegate = self
    tableView.dataSource = self
    return tableView
  }()
  /// Container for scope controls
  private lazy var scopeContainerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()
  /// Scope controls
  private lazy var searchScopeControls: UISegmentedControl = {
    let control = UISegmentedControl(items: viewModel.getSearchScopes())
    control.translatesAutoresizingMaskIntoConstraints = false
    control.selectedSegmentIndex = 0
    control.addTarget(self, action: #selector(updateSelectedScope), for: .valueChanged)
    return control
  }()
  /// Default artwork to be used
  var defaultArtwork: UIImage? {
    if let data = viewModel.defaultArtwork {
      return UIImage(data: data)
    }

    return nil
  }

  // MARK: - Lifecycle

  /// Initializer
  init(viewModel: SearchListViewModel) {
    super.init(nibName: nil, bundle: nil)
    self.viewModel = viewModel
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    setupSearchBar()
    addSubviews()
    addConstraints()
    setUpTheming()
    bindDataObserver()
    updateSelectedScope()
    observeKeyboardEvents()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    fadeInScopeControls()
    searchBar.searchTextField.becomeFirstResponder()
  }

  func setupSearchBar() {
    searchBar.placeholder = "Search \(viewModel.placeholderTitle)"
    searchBar.showsCancelButton = false
    searchBar.returnKeyType = .done
    searchBar.enablesReturnKeyAutomatically = false
    searchBar.delegate = self
    navigationItem.titleView = searchBar
    navigationItem.largeTitleDisplayMode = .never

    definesPresentationContext = true
    searchScopeControls.alpha = 0
  }

  func addSubviews() {
    scopeContainerView.addSubview(searchScopeControls)
    view.addSubview(scopeContainerView)
    view.addSubview(tableView)
  }

  func addConstraints() {
    let safeLayoutGuide = view.safeAreaLayoutGuide

    NSLayoutConstraint.activate([
      scopeContainerView.topAnchor.constraint(equalTo: safeLayoutGuide.topAnchor),
      scopeContainerView.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor),
      scopeContainerView.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor),
      scopeContainerView.heightAnchor.constraint(equalToConstant: 45),
      searchScopeControls.centerXAnchor.constraint(equalTo: scopeContainerView.centerXAnchor),
      searchScopeControls.centerYAnchor.constraint(equalTo: scopeContainerView.centerYAnchor),
      searchScopeControls.widthAnchor.constraint(equalToConstant: scopeItemWidth * 2),
      tableView.topAnchor.constraint(equalTo: scopeContainerView.bottomAnchor),
      tableView.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: safeLayoutGuide.bottomAnchor),
    ])
  }

  func bindDataObserver() {
    viewModel.items.sink { [weak self] _ in
      self?.tableView.reloadData()
    }.store(in: &disposeBag)
  }

  func fadeInScopeControls() {
    UIView.animate(withDuration: 0.5, delay: 0) { [weak self] in
      self?.searchScopeControls.alpha = 1
    }
  }

  @objc func updateSelectedScope() {
    viewModel.filterItems(query: searchBar.text, scopeIndex: searchScopeControls.selectedSegmentIndex)
  }
}

// MARK: - Table delegate

extension SearchListViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return UITableView.automaticDimension
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    viewModel.handleItemSelection(at: indexPath.row)
  }

  func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    guard indexPath.row == (self.viewModel.items.value.count - 1) else { return }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      self.viewModel.loadNextItems(
        query: self.searchBar.text,
        scopeIndex: self.searchScopeControls.selectedSegmentIndex
      )
    }
  }
}

extension SearchListViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return viewModel.items.value.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    // swiftlint:disable force_cast
    let cell = tableView.dequeueReusableCell(withIdentifier: "BookCellView", for: indexPath) as! BookCellView
    // swiftlint:enable force_cast

    let item = viewModel.items.value[indexPath.row]

    cell.title = item.title
    cell.subtitle = item.details
    cell.progress = item.progress
    cell.duration = item.durationFormatted
    cell.type = item.type
    cell.playbackState = viewModel.getPlaybackState(for: item)

    cell.artworkView.kf.setImage(
      with: ArtworkService.getArtworkProvider(for: item.relativePath),
      placeholder: self.defaultArtwork,
      options: [.targetCache(ArtworkService.cache)]
    )
    cell.setAccessibilityLabels()
    return cell
  }
}

// MARK: - Search delegate

extension SearchListViewController: UISearchBarDelegate {
  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    viewModel.scheduleSearchJob(query: searchText, scopeIndex: searchScopeControls.selectedSegmentIndex)
  }

  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    searchBar.searchTextField.resignFirstResponder()
  }
}

// MARK: - Themeable

extension SearchListViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    view.backgroundColor = theme.secondarySystemBackgroundColor
    tableView.backgroundColor = theme.systemBackgroundColor
    tableView.separatorColor = theme.separatorColor
    scopeContainerView.backgroundColor = theme.systemBackgroundColor

    self.overrideUserInterfaceStyle = theme.useDarkVariant
      ? UIUserInterfaceStyle.dark
      : UIUserInterfaceStyle.light
    self.viewModel.updateDefaultArtwork(for: theme)
  }
}

// MARK: - Keyboard events

extension SearchListViewController {
  // register for keyboard notifications
  func observeKeyboardEvents() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardWillShow(_:)),
      name: UIResponder.keyboardWillShowNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardWillHide(_:)),
      name: UIResponder.keyboardWillHideNotification,
      object: nil
    )
  }

  @objc func keyboardWillShow(_ notification: Notification) {
    let infoKey = UIResponder.keyboardFrameEndUserInfoKey
    if let keyboardFrame = (notification.userInfo?[infoKey] as? NSValue)?.cgRectValue {
      tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardFrame.size.height, right: 0)
    }
  }

  @objc func keyboardWillHide(_ notification: Notification) {
    /// Adjust for mini player too
    tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 88, right: 0)
  }
}
