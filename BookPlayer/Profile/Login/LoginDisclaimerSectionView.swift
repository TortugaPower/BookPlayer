//
//  LoginDisclaimerSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct LoginDisclaimerSectionView: View {
  @EnvironmentObject private var theme: ThemeViewModel

  /// The bullets under the shared heading. The default is the cloud pitch, where we do host
  /// the files; the media-server screen hosts nothing of theirs and says something different.
  let descriptions: [LocalizedStringKey]

  init(
    descriptions: [LocalizedStringKey] = [
      "benefits_disclaimer_account_description",
      "benefits_disclaimer_subscription_description",
    ]
  ) {
    self.descriptions = descriptions
  }

  var body: some View {
    Section {
      VStack(alignment: .leading, spacing: 10) {
        Text("benefits_disclaimer_title")
          .bpFont(.title)
        ForEach(descriptions.indices, id: \.self) { index in
          Text(descriptions[index])
            .bpFont(.body)
            .foregroundStyle(theme.secondaryColor)
        }
      }
    }
    .listRowBackground(Color.clear)
  }
}

#Preview {
  Form {
    LoginDisclaimerSectionView()
  }
  .environmentObject(ThemeViewModel())
}
