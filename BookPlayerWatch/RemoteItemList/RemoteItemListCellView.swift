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
  @ObservedObject var model: RemoteItemCellViewModel
  @State private var error: Error?

  var percentCompleted: String {
    guard model.item.progress > 0 else { return "" }

    if model.item.isFinished {
      return "100% - "
    } else {
      return "\(Int(model.item.percentCompleted))% - "
    }
  }

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(model.item.title)
          .lineLimit(2)
        Text(model.item.details)
          .font(.footnote)
          .foregroundColor(Color.secondary)
          .lineLimit(1)
        switch model.downloadState {
        case .downloading(let progress):
          LinearProgressView(value: progress)
            .frame(maxWidth: 100, maxHeight: 10)
        case .downloaded:
          Text(Image(systemName: "applewatch"))
            .font(.caption2)
            + Text(" - \(percentCompleted)\(model.item.durationFormatted)")
            .font(.footnote)
            .foregroundColor(Color.secondary)
        case .notDownloaded:
          Text(Image(systemName: "icloud.fill"))
            .font(.caption2)
            + Text(" - \(percentCompleted)\(model.item.durationFormatted)")
            .font(.footnote)
            .foregroundColor(Color.secondary)
        }
      }
      Spacer()
      if model.item.type == .folder {
        Image(systemName: "chevron.forward")
      }
    }
    .errorAlert(error: $error)
    .swipeActions {
      switch model.downloadState {
      case .downloading:
        Button {
          do {
            try model.cancelDownload()
          } catch {
            self.error = error
          }
        } label: {
          Image(systemName: "xmark.circle")
            .imageScale(.large)
        }
      case .downloaded:
        Button {
          do {
            try model.offloadItem()
          } catch {
            self.error = error
          }
        } label: {
          Image(systemName: "applewatch.slash")
            .imageScale(.large)
        }
      case .notDownloaded:
        Button {
          Task {
            do {
              try await model.startDownload()
            } catch {
              self.error = error
            }
          }
        } label: {
          Image(systemName: "icloud.and.arrow.down.fill")
            .imageScale(.large)
        }
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
