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
  let onDeleteTap: () -> Void
  let onWarningTap: () -> Void

  @EnvironmentObject var themeViewModel: ThemeViewModel

  var body: some View {
    HStack {
      Button {
        onDeleteTap()
      } label: {
        Image(systemName: "minus.circle.fill")
          .resizable()
          .scaledToFit()
          .frame(width: 22, height: 22)
          .foregroundColor(.red)
      }
      .padding(15)
      .accessibilitySortPriority(1)

      VStack(alignment: .leading, spacing: 2) {
        Text(item.title)
          .font(Font(Fonts.title))
          .foregroundColor(themeViewModel.primaryColor)

        VStack {
          Text(item.path)
          Text(item.formattedSize)
        }
        .font(.footnote)
        .foregroundColor(themeViewModel.secondaryColor)
      }
      .multilineTextAlignment(.leading)
      .padding(.trailing, item.showWarning ? 10 : 32)
      .accessibilityElement()
      .accessibilityLabel("\(item.title), \(item.formattedSize)")
      .accessibilitySortPriority(3)

      Spacer()

      Button {
        onWarningTap()
      } label: {
        Image(systemName: "exclamationmark.triangle.fill")
          .resizable()
          .scaledToFit()
          .frame(width: 22, height: 22)
          .foregroundColor(.yellow)
      }
      .padding(15)
      .accessibilitySortPriority(2)
      .opacity(item.showWarning ? 1 : 0)
    }
    .background(themeViewModel.systemBackgroundColor)
    .accessibilityElement(children: .contain)
  }

  init(item: StorageItem,
       onDeleteTap: @escaping () -> Void,
       onWarningTap: @escaping () -> Void) {
    self.item = item
    self.onDeleteTap = onDeleteTap
    self.onWarningTap = onWarningTap
  }
}

struct StorageRowView_Previews: PreviewProvider {
  static var previews: some View {
    VStack {
      StorageRowView(
        item: StorageItem(
          title: "Book title",
          fileURL: URL(fileURLWithPath: "book.mp3"),
          path: "book.mp3",
          size: 124,
          showWarning: true
        ),
        onDeleteTap: { },
        onWarningTap: { }
      )

      StorageRowView(
        item: StorageItem(
          title: "Book title",
          fileURL: URL(fileURLWithPath: "book.mp3"),
          path: "book.mp3",
          size: 124,
          showWarning: false
        ),
        onDeleteTap: { },
        onWarningTap: { }
      )
    }
    .padding()
    .environmentObject(ThemeViewModel())
    .previewLayout(.sizeThatFits)
  }
}
