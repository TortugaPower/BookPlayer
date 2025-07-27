//
//  RemoteItemListCellView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 18/11/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct RemoteItemListCellView: View {
  @ObservedObject var model: RemoteItemCellViewModel
  @State private var error: Error?
  var onTap: () -> Void

  let numberFormatter: NumberFormatter

  init(model: RemoteItemCellViewModel, onTap: @escaping () -> Void) {
    self.model = model
    let formatter = NumberFormatter()
    formatter.numberStyle = .percent
    formatter.maximumFractionDigits = 2
    self.numberFormatter = formatter
    self.onTap = onTap
  }

  var percentCompleted: String {
    guard model.item.progress > 0 else { return "" }

    if model.item.isFinished {
      return "100% - "
    } else {
      return "\(Int(model.item.percentCompleted))% - "
    }
  }
  
  var accessibilityDownloadStateLabel: String {
    switch model.downloadState {
    case .notDownloaded:
      return ". ☁️"
    case .downloading(let progress):
      return "\(Int(progress * 100))%"
    case .downloaded:
      return ". ⌚️"
    }
  }

  func formattedProgress(_ progress: Double) -> String {
    numberFormatter.string(from: NSNumber(value: progress)) ?? ""
  }

  var body: some View {
    Button(action: onTap) {
      HStack {
        VStack(alignment: .leading) {
          Text(model.item.title)
            .lineLimit(2)
          Text(model.item.details)
            .font(.footnote)
            .foregroundStyle(Color.secondary)
            .lineLimit(1)
          switch model.downloadState {
          case .downloading(let progress):
            HStack {
              if #available(watchOS 10.0, *) {
                Image(systemName: "icloud.and.arrow.down.fill")
                  .font(.caption2)
                  .symbolEffect(.pulse)
              } else {
                Image(systemName: "icloud.and.arrow.down.fill")
                  .font(.caption2)
              }
              LinearProgressView(value: progress, fillColor: .white)
                .frame(maxWidth: 70, maxHeight: 10)
              Text(formattedProgress(progress))
                .font(.footnote)
            }
          case .downloaded:
            Text(Image(systemName: "applewatch"))
              .font(.caption2)
              + Text(" - \(percentCompleted)\(model.item.durationFormatted)")
              .font(.footnote)
              .foregroundStyle(Color.secondary)
          case .notDownloaded:
            Text(Image(systemName: "icloud.fill"))
              .font(.caption2)
              + Text(" - \(percentCompleted)\(model.item.durationFormatted)")
              .font(.footnote)
              .foregroundStyle(Color.secondary)
          }
        }
        Spacer()
        if model.item.type == .folder {
          Image(systemName: "chevron.forward")
        }
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
        .accessibilityLabel("cancel_download_title".localized)
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
        .accessibilityLabel("remove_downloaded_file_title".localized)
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
        .accessibilityLabel("download_title".localized)
      }
    }
    .accessibilityLabel(VoiceOverService.getAccessibilityLabel(for: model.item) + accessibilityDownloadStateLabel)
  }
}

struct LinearProgressView<Shape: SwiftUI.Shape>: View {
  var value: Double
  var shape: Shape
  var fillColor: Color

  var body: some View {
    shape.fill(.secondary)
      .overlay(alignment: .leading) {
        GeometryReader { proxy in
          shape.fill(fillColor)
            .frame(width: proxy.size.width * value)
        }
      }
      .clipShape(shape)
  }
}

extension LinearProgressView where Shape == Capsule {
  init(value: Double, fillColor: Color, shape: Shape = Capsule()) {
    self.value = value
    self.shape = shape
    self.fillColor = fillColor
  }
}
