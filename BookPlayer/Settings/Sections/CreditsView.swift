//
//  CreditsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 20/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct CreditsView: View {
  @EnvironmentObject var theme: ThemeViewModel
  @State private var contents: AttributedString = ""

  var body: some View {
    ScrollView {
      Text(contents)
        .padding()
        .foregroundColor(theme.primaryColor)
    }
    .onAppear {
      loadFile()
    }
    .background(theme.systemBackgroundColor)
    .navigationTitle("settings_credits_title")
  }

  private func loadFile() {
    guard
      let path = Bundle.main.path(forResource: "Credits", ofType: "html"),
      let data = FileManager.default.contents(atPath: path),
      let nsAttributedString = try? NSAttributedString(
        data: data,
        options: [.documentType: NSAttributedString.DocumentType.html],
        documentAttributes: nil
      ),
      let attributedString = try? AttributedString(nsAttributedString, including: \.uiKit)
    else {
      contents = "Unable to display credits"
      return
    }

    contents = attributedString
  }
}

#Preview {
  CreditsView()
    .environmentObject(ThemeViewModel())
}
