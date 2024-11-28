//
//  RemoteItemListCellView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 18/11/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct RemoteItemListCellView: View {
  let item: SimpleLibraryItem

  var percentCompleted: String {
    guard item.progress > 0 else { return "" }

    if item.isFinished {
      return "100% - "
    } else {
      return "\(Int(item.percentCompleted))% - "
    }
  }

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(item.title)
          .lineLimit(2)
        Text(item.details)
          .font(.footnote)
          .foregroundColor(Color.secondary)
          .lineLimit(1)
        Text("\(percentCompleted)\(item.durationFormatted)")
          .font(.footnote)
          .foregroundColor(Color.secondary)
          .lineLimit(1)
      }
      Spacer()
      if item.type == .folder {
        Image(systemName: "chevron.forward")
      }
    }
  }
}

struct LinearProgressView<Shape: SwiftUI.Shape>: View {
  var value: Double
  var shape: Shape

  var body: some View {
    shape.fill(.secondary)
      .overlay(alignment: .leading) {
        GeometryReader { proxy in
          shape.fill(.white)
            .frame(width: proxy.size.width * value)
        }
      }
      .clipShape(shape)
  }
}

extension LinearProgressView where Shape == Capsule {
  init(value: Double, shape: Shape = Capsule()) {
    self.value = value
    self.shape = shape
  }
}
