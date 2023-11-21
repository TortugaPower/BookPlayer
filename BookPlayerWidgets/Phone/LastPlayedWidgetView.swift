//
//  LastPlayedWidgetView.swift
//  BookPlayerWidgetUIExtension
//
//  Created by Gianni Carlo on 24/11/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import WidgetKit

struct LastPlayedProvider: TimelineProvider {
  typealias Entry = SimpleEntry

  func placeholder(in context: Context) -> SimpleEntry {
    SimpleEntry(
      date: Date(),
      title: "Last played book title",
      relativePath: nil
    )
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (Entry) -> Void
  ) {
    Task {
      do {
        let entry = try await getEntryForTimeline(
          context: context
        )
        completion(entry)
      } catch {
        completion(placeholder(in: context))
      }
    }
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<Entry>) -> Void
  ) {
    Task {
      do {
        let entry = try await getEntryForTimeline(context: context)

        completion(Timeline(entries: [entry], policy: .never))
      } catch {
        completion(Timeline(entries: [], policy: .never))
      }
    }
  }

  func getEntryForTimeline(
    context: Context
  ) async throws -> SimpleEntry {
    let stack = try await DatabaseInitializer().loadCoreDataStack()
    let dataManager = DataManager(coreDataStack: stack)
    let libraryService = LibraryService(dataManager: dataManager)

    guard
      let lastPlayedItem = libraryService.getLastPlayedItems(limit: 1)?.first
    else {
      throw BookPlayerError.emptyResponse
    }

    let isPlaying = true

    let theme = libraryService.getLibraryCurrentTheme() ?? SimpleTheme.getDefaultTheme()

    let entry = SimpleEntry(
      date: Date(),
      title: lastPlayedItem.title,
      relativePath: lastPlayedItem.relativePath,
      theme: theme,
      isPlaying: isPlaying
    )

    return entry
  }
}

struct LastPlayedWidgetView: View {
  @Environment(\.colorScheme) var colorScheme
  var entry: LastPlayedProvider.Entry

  func getArtworkView(for relativePath: String) -> some View {
    ZStack {
      Image(uiImage: UIImage(contentsOfFile: ArtworkService.getCachedImageURL(for: relativePath).path)
            ?? ArtworkService.generateDefaultArtwork(from: entry.theme.linkColor)!)
      .resizable()
      .frame(width: 90, height: 90)
      .aspectRatio(1.0, contentMode: .fit)
      .cornerRadius(8.0)
    }
  }

  var body: some View {
    let titleLabel = entry.title ?? "---"

    let widgetColors = WidgetUtils.getColors(from: entry.theme, with: colorScheme)

    let imageName = entry.isPlaying ? "pause.fill" : "play.fill"

    let appIconName = WidgetUtils.getAppIconName()

    return VStack(alignment: .leading) {
      HStack {
        if let relativePath = entry.relativePath {
          if #available(iOSApplicationExtension 17.0, iOS 17.0, *) {
            Button(intent: BookStartPlaybackIntent(relativePath: relativePath)) {
              ZStack {
                getArtworkView(for: relativePath)
                Circle()
                  .foregroundColor(.white)
                  .frame(width: 30, height: 30)
                  .opacity(0.8)
                Image(systemName: imageName)
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .foregroundColor(.black)
                  .frame(width: 11, height: 11)
                  .offset(x: 1)
              }
            }
            .buttonStyle(.plain)
          } else {
            getArtworkView(for: relativePath)
          }
        } else {
          Rectangle()
            .fill(Color.secondary)
            .frame(width: 90, height: 90)
            .aspectRatio(1.0, contentMode: .fit)
            .cornerRadius(8.0)
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
          .foregroundColor(widgetColors.primaryColor)
          .font(.footnote)
          .lineLimit(2)
          .accessibility(hidden: true)
      }
      .frame(height: 40)
      .padding([.leading, .trailing], 15)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .widgetBackground(backgroundView: widgetColors.backgroundColor)
  }
}

struct LastPlayedWidgetView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      LastPlayedWidgetView(entry: SimpleEntry(
        date: Date(),
        title: "Test Book Title",
        relativePath: nil
      ))
      .previewContext(WidgetPreviewContext(family: .systemSmall))
      LastPlayedWidgetView(entry: SimpleEntry(
        date: Date(),
        title: nil,
        relativePath: nil
      ))
      .previewContext(WidgetPreviewContext(family: .systemSmall))
      LastPlayedWidgetView(entry: SimpleEntry(
        date: Date(),
        title: "Test Book Title",
        relativePath: nil
      ))
      .previewContext(WidgetPreviewContext(family: .systemSmall))
      .environment(\.colorScheme, .dark)
      LastPlayedWidgetView(entry: SimpleEntry(
        date: Date(),
        title: nil,
        relativePath: nil
      ))
      .previewContext(WidgetPreviewContext(family: .systemSmall))
      .environment(\.colorScheme, .dark)
    }
  }
}

struct LastPlayedWidget: Widget {
  let kind: String = "com.bookplayer.widget.small.lastPlayed"

  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: kind,
      provider: LastPlayedProvider(),
      content: { entry in
        LastPlayedWidgetView(entry: entry)
      }
    )
    .configurationDisplayName("Last Played Book")
    .description("See and play your last played book")
    .supportedFamilies([.systemSmall])
    .contentMarginsDisabledIfAvailable()
  }
}
