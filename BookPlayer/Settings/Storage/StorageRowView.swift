//
//  StorageRowView.swift
//  BookPlayer
//
//  Created by Dmitrij Hojkolov on 28.06.2023.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import SwiftUI
import BookPlayerKit

struct StorageRowView: View {
  let item: StorageItem
  let onDeleteTap: (() -> Void)?
  let onWarningTap: (() -> Void)?

  @EnvironmentObject var themeViewModel: ThemeViewModel

  var body: some View {
    HStack {
      Button {
        onDeleteTap?()
      } label: {
        Image(systemName: "minus.circle.fill")
          .resizable()
          .scaledToFit()
          .frame(width: 22, height: 22)
          .foregroundColor(.red)
      }
      .padding(15)

      VStack(alignment: .leading, spacing: 2) {
        Text(item.title)
          .font(Font(Fonts.title))
          .multilineTextAlignment(.leading)
          .foregroundColor(themeViewModel.primaryColor)

        Text(item.path)
          .font(.footnote)
          .multilineTextAlignment(.leading)
          .foregroundColor(themeViewModel.secondaryColor)

        Text(item.formattedSize)
          .font(.footnote)
          .multilineTextAlignment(.leading)
          .foregroundColor(themeViewModel.secondaryColor)
      }
      .padding(.trailing, item.showWarning ? 10 : 32)

      Spacer()

      if item.showWarning {
        Button {
          onWarningTap?()
        } label: {
          Image(systemName: "exclamationmark.triangle.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 22, height: 22)
            .foregroundColor(.yellow)
        }
        .padding(15)
      }
    }
    .background(themeViewModel.systemBackgroundColor)
  }

  init(item: StorageItem, onDeleteTap: ( () -> Void)?, onWarningTap: ( () -> Void)?) {
    self.item = item
    self.onDeleteTap = onDeleteTap
    self.onWarningTap = onWarningTap
  }
}

struct StorageRowView_Previews: PreviewProvider {
  static var previews: some View {
    StorageRowView(
      item: StorageItem(
        title: "Book title",
        fileURL: URL(fileURLWithPath: "book.mp3"),
        path: "book.mp3",
        size: 124,
        showWarning: true
      ),
      onDeleteTap: nil,
      onWarningTap: nil
    )
    .environmentObject(ThemeViewModel())
  }
}
