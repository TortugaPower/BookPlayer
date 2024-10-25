//
//  JellyfinConnectionViewController.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-25.
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
      if let _ = task {
        self?.navBarRightButtonEnabledWatcher = nil
        self?.navigationItem.rightBarButtonItem?.isEnabled = false
      } else if let self = self {
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
            title: "jellyfin_login_button".localized,
            style: .done,
            target: self,
            action: #selector(self.didTapLogin)
          )
          navBarRightButtonEnabledWatcher = Publishers.CombineLatest3(viewModel.form.$username, viewModel.form.$password, $apiClient).sink { [weak self] (username, password, apiClient) in
            self?.navigationItem.rightBarButtonItem?.isEnabled = apiClient != nil && !username.isEmpty && !password.isEmpty
          }
        case .connected:
          navBarRightButtonEnabledWatcher = nil
          self.navigationItem.rightBarButtonItem?.isEnabled = false
        }
      }
    }
    .store(in: &disposeBag)
  }

  @objc func didTapCancel() {
    viewModel.handleCancelAction()
  }

  @objc func didTapConnect() {
    if let _ = apiTask {
      return
    }

    let mainBundleInfo = Bundle.main.infoDictionary
    let clientName = mainBundleInfo?[kCFBundleNameKey as String] as? String
    let clientVersion = mainBundleInfo?[kCFBundleVersionKey as String] as? String
    let deviceID = UIDevice.current.identifierForVendor
    if let url = URL(string: viewModel.form.serverUrl), let clientName, let clientVersion, let deviceID {
      let configuration = JellyfinClient.Configuration(
        url: url,
        client: clientName,
        deviceName: UIDevice.current.name,
        deviceID: "\(deviceID.uuidString)-\(clientName)",
        version: clientVersion
      )
      let apiClient = JellyfinClient(configuration: configuration)

      apiTask = Task {
        defer { self.apiTask = nil }
        let publicSystemInfo = try await apiClient.send(Paths.getPublicSystemInfo)
        self.viewModel.connectionState = .foundServer
        self.viewModel.form.serverName = publicSystemInfo.value.serverName
        self.apiClient = apiClient
      }
    }
  }

  @objc func didTapLogin() {
    if let _ = apiTask {
      return
    }
    if let apiClient {
      let username = viewModel.form.username
      let password = viewModel.form.password
      apiTask = Task {
        defer { self.apiTask = nil }
        let authResult = try await apiClient.signIn(username: username, password: password)
        if let _ = authResult.accessToken {
          self.viewModel.connectionState = .connected
          self.viewModel.handleConnectedEvent(forClient: apiClient)
        }
        self.apiTask = nil
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
