//
//  IntegrationSettingsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct IntegrationSettingsView<VM: IntegrationConnectionViewModelProtocol>: View {
  /// Owned by this view so transient state (pending custom header edits, etc.) survives
  /// parent re-renders that would otherwise rebuild an `@ObservedObject`-passed viewmodel.
  @StateObject private var viewModel: VM

  let integrationName: String

  init(integrationName: String, initViewModel: @escaping () -> VM) {
    self._viewModel = .init(wrappedValue: initViewModel())
    self.integrationName = integrationName
  }

  var body: some View {
    IntegrationConnectionView(viewModel: viewModel, integrationName: integrationName)
      .navigationBarTitleDisplayMode(.inline)
  }
}
