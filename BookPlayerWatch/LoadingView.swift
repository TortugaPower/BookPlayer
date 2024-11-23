//
//  LoadingView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 21/11/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

struct LoadingView: View {
  @EnvironmentObject private var appDelegate: ExtensionDelegate

  var body: some View {
    if let coreServices = appDelegate.coreServices {
      RootView(coreServices: coreServices)
    } else {
      ProgressView()
    }
  }
}

#Preview {
  LoadingView()
}
