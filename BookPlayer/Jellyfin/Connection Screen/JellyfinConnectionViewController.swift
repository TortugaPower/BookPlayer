//
//  JellyfinConnectionViewController.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-25.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import JellyfinAPI
import SwiftUI
import Themeable
import UIKit

class JellyfinConnectionViewController: UIViewController, MVVMControllerProtocol {
  var viewModel: JellyfinConnectionViewModel!

  private var disposeBag = Set<AnyCancellable>()
  private var navBarRightButtonEnabledWatcher: AnyCancellable?

  @Published private var apiClient: JellyfinClient?
  @Published private var apiTask: Task<(), any Error>?

  // MARK: - UI components

  private lazy var contentView: UIView = {
    let view = JellyfinConnectionView(viewModel: viewModel)
    let hostingController = UIHostingController(rootView: view)
    addChild(hostingController)
    hostingController.didMove(toParent: self)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    return hostingController.view
  }()

  // MARK: - Initializer

  init(viewModel: JellyfinConnectionViewModel) {
    super.init(nibName: nil, bundle: nil)
    self.viewModel = viewModel
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    setupNavigationItem()
    addSubviews()
    addConstraints()
    setUpTheming()
    bindConnectionObservers()
  }

  private func setupNavigationItem() {
    self.navigationItem.title = "jellyfin_connection_title".localized
    self.navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .cancel,
      target: self,
      action: #selector(self.didTapCancel)
    )
    definesPresentationContext = true
  }

  private func addSubviews() {
    view.addSubview(contentView)
  }

  private func addConstraints() {
    let safeLayoutGuide = view.safeAreaLayoutGuide

    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: safeLayoutGuide.topAnchor),
      contentView.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: safeLayoutGuide.bottomAnchor),
    ])
  }

  private func bindConnectionObservers() {
    Publishers.CombineLatest(viewModel.$connectionState, $apiTask).sink { [weak self] (state, task) in
      guard let self = self else {
        return
      }
      if let _ = task {
        self.navBarRightButtonEnabledWatcher?.cancel()
        self.navBarRightButtonEnabledWatcher = nil
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        return
      }
      switch state {
      case .disconnected:
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
          title: "jellyfin_connect_button".localized,
          style: .done,
          target: self,
          action: #selector(self.didTapConnect)
        )
        navBarRightButtonEnabledWatcher = viewModel.form.$serverUrl.map { !$0.isEmpty }.sink { [weak self] canConnect in
          self?.navigationItem.rightBarButtonItem?.isEnabled = canConnect
        }
      case .foundServer:
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
          title: "jellyfin_sign_in_button".localized,
          style: .done,
          target: self,
          action: #selector(self.didTapLogin)
        )
        navBarRightButtonEnabledWatcher = Publishers.CombineLatest3(viewModel.form.$username, viewModel.form.$password, $apiClient).sink { [weak self] (username, password, apiClient) in
          self?.navigationItem.rightBarButtonItem?.isEnabled = apiClient != nil && !username.isEmpty && !password.isEmpty
        }
      case .connected:
        self.navBarRightButtonEnabledWatcher?.cancel()
        self.navBarRightButtonEnabledWatcher = nil
        self.navigationItem.rightBarButtonItem = nil
      }
    }
    .store(in: &disposeBag)
  }

  @objc func didTapCancel() {
    viewModel.handleCancelAction()
  }

  @objc func didTapConnect() {
    if apiTask != nil {
      return
    }

    guard let apiClient = JellyfinCoordinator.createClient(serverUrlString: viewModel.form.serverUrl) else {
      return
    }

    apiTask = Task {
      defer { self.apiTask = nil }
      let publicSystemInfo = try await apiClient.send(Paths.getPublicSystemInfo)
      self.viewModel.connectionState = .foundServer
      self.viewModel.form.serverName = publicSystemInfo.value.serverName
      self.apiClient = apiClient
    }
  }

  @objc func didTapLogin() {
    if apiTask != nil {
      return
    }
    guard let apiClient else {
      return
    }
    let username = viewModel.form.username
    let password = viewModel.form.password
    apiTask = Task {
      defer { self.apiTask = nil }
      let authResult = try await apiClient.signIn(username: username, password: password)
      if let _ = authResult.accessToken, let userID = authResult.user?.id {
        self.viewModel.connectionState = .connected
        self.viewModel.handleConnectedEvent(userID: userID, client: apiClient)
      }
    }
  }
}

// MARK: - Themeable

extension JellyfinConnectionViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    contentView.backgroundColor = theme.systemGroupedBackgroundColor
  }
}
