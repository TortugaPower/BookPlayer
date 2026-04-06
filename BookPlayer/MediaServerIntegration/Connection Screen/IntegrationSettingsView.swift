//
//  IntegrationSettingsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct IntegrationSettingsView<VM: IntegrationConnectionViewModelProtocol>: View {
  @ObservedObject var viewModel: VM

  let integrationName: String

  var body: some View {
    IntegrationConnectionView(viewModel: viewModel, integrationName: integrationName)
      .navigationBarTitleDisplayMode(.inline)
  }
}
