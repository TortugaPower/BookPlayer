//
//  LastPlayedView.swift
//  BookPlayerWidgetsPhone
//
//  Created by Gianni Carlo on 30/9/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import WidgetKit

struct LastPlayedView: View {
  @Environment(\.colorScheme) var colorScheme
  var model: LastPlayedModel

  func getArtworkView(for relativePath: String) -> some View {
    ZStack {
      if let uiImage = WidgetUtils.getArtworkImage(
        for: relativePath,
        theme: model.theme
      ) {
        Image(
          uiImage: uiImage
        )
        .resizable()
        .frame(width: 90, height: 90)
        .aspectRatio(1.0, contentMode: .fit)
        .cornerRadius(8.0)
      } else {
        Rectangle()
          .frame(width: 90, height: 90)
          .foregroundStyle(Color.gray.opacity(0.2))
          .cornerRadius(8.0)
      }
    }
  }

  var body: some View {
    let titleLabel = model.title ?? "---"

    let widgetColors = WidgetUtils.getColors(from: model.theme, with: colorScheme)

    let imageName = model.isPlaying ? "pause.fill" : "play.fill"

    let appIconName = WidgetUtils.getAppIconName()

    return VStack(alignment: .leading) {
      if let relativePath = model.relativePath {
        HStack {
          if #available(iOSApplicationExtension 17.0, iOS 17.0, *) {
            Button(intent: BookPlaybackToggleIntent(relativePath: relativePath)) {
              ZStack {
                getArtworkView(for: relativePath)
                Circle()
                  .foregroundStyle(.white)
                  .frame(width: 30, height: 30)
                  .opacity(0.8)
                Image(systemName: imageName)
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .foregroundStyle(.black)
                  .frame(width: 11, height: 11)
                  .offset(x: model.isPlaying ? 0 : 1)
              }
            }
            .buttonStyle(.plain)
          } else {
            getArtworkView(for: relativePath)
          }

          VStack {
            Image(appIconName)
              .accessibility(hidden: true)
              .frame(width: 32, height: 32)
              .padding([.trailing], 10)
              .cornerRadius(8.0)
            Spacer()
          }
        }
        .frame(height: 90)
        .padding([.leading])
        .padding([.top], 8)
        .accessibility(label: Text("Last Played Book, \(titleLabel)"))
        VStack(alignment: .leading) {
          Text(titleLabel)
            .fontWeight(.semibold)
            .foregroundStyle(widgetColors.primaryColor)
            .font(.footnote)
            .lineLimit(2)
            .accessibility(hidden: true)
        }
        .frame(height: 40)
        .padding([.leading, .trailing], 15)
      } else {
        Image(.logoNobackground)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .widgetBackground(backgroundView: widgetColors.backgroundColor)
  }
}
