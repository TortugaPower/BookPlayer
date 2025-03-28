//
//  BookmarksView.swift
//  BookPlayerWatch
//
//  Created by GC on 1/10/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct BookmarksView: View {
  @StateObject var model: BookmarksViewModel

  @State var error: Error?

  @Environment(\.dismiss) var dismiss

  var body: some View {
    List {
      HStack {
        Spacer()
        Button {
          do {
            try model.createBookmark()
          } catch {
            self.error = error
          }
        } label: {
          Image(systemName: "plus.circle.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
        }
        .buttonStyle(PlainButtonStyle())
        Spacer()
      }
      .frame(height: 24)
      .listRowBackground(Color.clear)

      Section {
        ForEach(model.userBookmarks) { bookmark in
          Button {
            model.playerManager.jumpTo(bookmark.time + 0.01, recordBookmark: false)
            dismiss()
          } label: {
            VStack(alignment: .leading) {
              Text(TimeParser.formatTime(bookmark.time))
                .foregroundColor(Color.secondary)
                .font(.footnote)
              if let note = bookmark.note {
                Text(note)
              }
            }
            .frame(minHeight: 24)
            .padding(.vertical, Spacing.S4)
          }
          .swipeActions {
            Button(
              role: .destructive,
              action: { model.deleteBookmark(bookmark) },
              label: {
                Image(systemName: "trash")
                  .imageScale(.large)
              }
            )
            .accessibilityLabel("delete_button".localized)
          }
        }
      } header: {
        Text("bookmark_type_user_title".localized)
          .foregroundStyle(Color.accentColor)
      }

      Section {
        ForEach(model.automaticBookmarks) { bookmark in
          Button {
            model.playerManager.jumpTo(bookmark.time + 0.01, recordBookmark: false)
            dismiss()
          } label: {
            VStack(alignment: .leading) {
              HStack {
                Text(TimeParser.formatTime(bookmark.time))
                  .foregroundColor(Color.secondary)
                  .font(.footnote)
                Spacer()
                if let imageName = bookmark.getImageNameForType() {
                  Image(systemName: imageName)
                    .foregroundColor(Color.secondary)
                }
              }
              if let note = bookmark.note {
                Text(note)
              }
            }
          }
        }
      } header: {
        Text("bookmark_type_automatic_title".localized)
          .foregroundStyle(Color.accentColor)
          .padding(.top, 10)
      }
    }
    .environment(\.defaultMinListRowHeight, 1)
    .customListSectionSpacing(0)
    .errorAlert(error: $error)
    .navigationTitle("bookmarks_title")
  }
}
