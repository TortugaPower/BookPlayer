//
//  HardcoverBookRow.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/28/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct HardcoverBookRow: View {
  @EnvironmentObject var themeViewModel: ThemeViewModel

  let viewModel: Model

  var body: some View {
    HStack(spacing: 12) {
      if let url = viewModel.artworkURL {
        AsyncImage(url: url) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.3))
            .overlay {
              ProgressView()
            }
        }
        .frame(width: 60, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(viewModel.title)
          .font(.headline)
          .foregroundColor(themeViewModel.primaryColor)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)

        Text(viewModel.author)
          .font(.subheadline)
          .foregroundColor(themeViewModel.secondaryColor)
          .foregroundColor(.secondary)
      }
    }
    .padding(.vertical, 4)
    .contentShape(Rectangle())
  }
}

extension HardcoverBookRow {
  struct Model {
    var id: Int
    var artworkURL: URL?
    var title: String
    var author: String
  }
}
