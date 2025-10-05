//
//  BookmarksView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/10/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct BookmarksView: View {
  @AppStorage(Constants.UserDefaults.isAutomaticBookmarksSectionCollapsed)
  private var isAutomaticBookmarksSectionCollapsed: Bool = false
  @StateObject private var model: Self.Model
  @StateObject private var theme = ThemeViewModel()

  @State private var showingNoteAlert: SimpleBookmark?
  @State private var bookmarkToDelete: SimpleBookmark?
  @State private var noteText: String = ""

  @Environment(\.dismiss) private var dismiss

  var deleteAlertTitle: String {
    if let bookmarkToDelete {
      return String(format: "delete_single_item_title".localized, TimeParser.formatTime(bookmarkToDelete.time))
    } else {
      return "delete_single_item_title".localized
    }
  }

  init(initModel: @escaping () -> Self.Model) {
    self._model = .init(wrappedValue: initModel())
  }

  var body: some View {
    NavigationStack {
      List {
        // Automatic bookmarks section
        Section(
          isExpanded: $isAutomaticBookmarksSectionCollapsed,
          content: {
            ForEach(model.automaticBookmarks) { bookmark in
              bookmarkRow(bookmark)
            }
          },
          header: {
            Text("bookmark_type_automatic_title")
              .foregroundStyle(theme.primaryColor)
          }
        )

        // User bookmarks section
        Section {
          ForEach(model.userBookmarks) { bookmark in
            bookmarkRow(bookmark)
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                  bookmarkToDelete = bookmark
                } label: {
                  Image(systemName: "trash")
                    .foregroundStyle(Color.red)
                }
                .accessibilityLabel("delete_button")

                Button {
                  noteText = bookmark.note ?? ""
                  showingNoteAlert = bookmark
                } label: {
                  Image(systemName: "pencil")
                }
                .accessibilityLabel("bookmark_note_edit_title")
              }
          }
        } header: {
          Text("bookmark_type_user_title".localized)
            .foregroundStyle(theme.primaryColor)
        }
      }
      .listStyle(.sidebar)
      .applyListStyle(with: theme, background: theme.systemBackgroundColor)
      .navigationTitle("bookmarks_title")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .foregroundStyle(theme.linkColor)
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          // TODO: Implement export using SwiftUI ShareLink and Transferable protocol
          // Create a struct conforming to Transferable that can export bookmarks as text
          // Use ShareLink(item: transferableBookmarks) { Label("Share", systemImage: "square.and.arrow.up") }
          Button {
            model.exportBookmarks()
          } label: {
            Image(systemName: "square.and.arrow.up")
              .foregroundStyle(theme.linkColor)
          }
        }
      }
      .alert(
        "bookmark_note_action_title".localized,
        isPresented: .constant(showingNoteAlert != nil),
        presenting: showingNoteAlert
      ) { bookmark in
        TextField("note_title".localized, text: $noteText)
        Button("cancel_button".localized, role: .cancel) {
          showingNoteAlert = nil
          noteText = ""
        }
        Button("ok_button".localized) {
          model.addNote(noteText, bookmark: bookmark)
          showingNoteAlert = nil
          noteText = ""
        }
      }
      .alert(
        "",
        isPresented: .constant(bookmarkToDelete != nil),
        presenting: bookmarkToDelete
      ) { bookmark in
        Button("cancel_button".localized, role: .cancel) {
          bookmarkToDelete = nil
        }
        Button("delete_button".localized, role: .destructive) {
          model.deleteBookmark(bookmark)
          bookmarkToDelete = nil
        }
      } message: { bookmark in
        Text(String(format: "delete_single_item_title".localized, TimeParser.formatTime(bookmark.time)))
      }
    }
  }

  @ViewBuilder
  private func bookmarkRow(_ bookmark: SimpleBookmark) -> some View {
    Button {
      model.handleBookmarkSelected(bookmark)
      dismiss()
    } label: {
      HStack(spacing: Spacing.S2) {
        Text(TimeParser.formatTime(bookmark.time))
          .frame(minWidth: 61)
          .bpFont(Fonts.caption)
          .foregroundStyle(theme.secondaryColor)

        if let note = bookmark.note {
          Text(note)
            .bpFont(Fonts.body)
            .foregroundStyle(theme.primaryColor)
        }

        Spacer()

        if let imageName = bookmark.getImageNameForType() {
          Image(systemName: imageName)
            .foregroundStyle(theme.secondaryColor)
        }
      }
    }
    .listRowBackground(theme.secondarySystemBackgroundColor)
  }
}

extension BookmarksView {
  class Model: ObservableObject {
    @Published var automaticBookmarks = [SimpleBookmark]()
    @Published var userBookmarks = [SimpleBookmark]()

    var isAutomaticSectionCollapsed: Bool {
      get {
        UserDefaults.standard.bool(forKey: Constants.UserDefaults.isAutomaticBookmarksSectionCollapsed)
      }
      set {
        UserDefaults.standard.set(
          newValue,
          forKey: Constants.UserDefaults.isAutomaticBookmarksSectionCollapsed
        )
      }
    }

    init(
      automaticBookmarks: [SimpleBookmark] = [],
      userBookmarks: [SimpleBookmark] = []
    ) {
      self.automaticBookmarks = automaticBookmarks
      self.userBookmarks = userBookmarks
    }

    func handleBookmarkSelected(_ bookmark: SimpleBookmark) {}
    func deleteBookmark(_ bookmark: SimpleBookmark) {}
    func addNote(_ note: String, bookmark: SimpleBookmark) {}
    func exportBookmarks() {}
  }
}

#Preview {
  @Previewable var bookmark1 = SimpleBookmark(
    time: 123.45,
    note: "Important scene",
    type: .user,
    relativePath: "book1.m4b"
  )

  @Previewable var bookmark2 = SimpleBookmark(
    time: 456.78,
    note: nil,
    type: .user,
    relativePath: "book1.m4b"
  )

  @Previewable var automaticBookmark = SimpleBookmark(
    time: 789.12,
    note: "bookmark_automatic_play_title".localized,
    type: .play,
    relativePath: "book1.m4b"
  )

  BookmarksView {
    .init(
      automaticBookmarks: [automaticBookmark],
      userBookmarks: [bookmark1, bookmark2]
    )
  }
}
