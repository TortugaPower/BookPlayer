// swiftlint:disable all
// swift-format-ignore-file
// AnyLint.skipInFile: All

// This file is maintained by ReMafoX (https://remafox.app) – manual edits will be overridden.

import Foundation
import SwiftUI

/// Top-level shortcut for ``Res.Str``. Provides safe access to localized strings. Managed by ReMafoX (https://remafox.app).
internal typealias Loc = Res.Str

/// Top-level namespace for safe resource access. Managed by ReMafoX (https://remafox.app).
internal enum Res {
    /// Root namespace for safe access to localized strings. Managed by ReMafoX (https://remafox.app).
    internal enum Str {
        /// 🇺🇸 English: "On"
        internal enum ActiveTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "active_title" }
        }

        /// 🇺🇸 English: "Audio Source"
        internal enum AudioSourceTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "audio_source_title" }
        }

        /// 🇺🇸 English: "Book duration:"
        internal enum BookDurationTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "book_duration_title" }
        }

        /// 🇺🇸 English: "Current Book Time: %@"
        internal struct BookTimeCurrentTitle {
            internal let unnamedParam1: String

            internal init(_ unnamedParam1: String) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'book_time_current_title' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "book_time_current_title" }
        }

        /// 🇺🇸 English: "Remaining Book Time:"
        internal enum BookTimeRemainingTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "book_time_remaining_title" }
        }

        /// 🇺🇸 English: "Last position before playback started"
        internal enum BookmarkAutomaticPlayTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "bookmark_automatic_play_title" }
        }

        /// 🇺🇸 English: "Last position before time skip"
        internal enum BookmarkAutomaticSkipTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "bookmark_automatic_skip_title" }
        }

        /// 🇺🇸 English: "Create Bookmark"
        internal enum BookmarkCreateTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "bookmark_create_title" }
        }

        /// 🇺🇸 English: "Your bookmark has been saved at %@"
        internal struct BookmarkCreatedTitle {
            internal let unnamedParam1: String

            internal init(_ unnamedParam1: String) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'bookmark_created_title' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "bookmark_created_title" }
        }

        /// 🇺🇸 English: "You have already created a bookmark at %@"
        internal struct BookmarkExistsTitle {
            internal let unnamedParam1: String

            internal init(_ unnamedParam1: String) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'bookmark_exists_title' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "bookmark_exists_title" }
        }

        /// 🇺🇸 English: "Add note"
        internal enum BookmarkNoteActionTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "bookmark_note_action_title" }
        }

        /// 🇺🇸 English: "Edit note"
        internal enum BookmarkNoteEditTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "bookmark_note_edit_title" }
        }

        /// 🇺🇸 English: "Automatic"
        internal enum BookmarkTypeAutomaticTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "bookmark_type_automatic_title" }
        }

        /// 🇺🇸 English: "Manual"
        internal enum BookmarkTypeUserTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "bookmark_type_user_title" }
        }

        /// 🇺🇸 English: "See bookmarks"
        internal enum BookmarksSeeTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "bookmarks_see_title" }
        }

        /// 🇺🇸 English: "Bookmarks"
        internal enum BookmarksTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "bookmarks_title" }
        }

        /// 🇺🇸 English: "BookPlayer is free and Open Source and it will always remain that way. With your help we are able to implement more features and make BookPlayer even better"
        internal enum BookplayerOpensourceDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "bookplayer_opensource_description" }
        }

        /// 🇺🇸 English: "Make sure items are in correct order. To reorder chapters later you need convert the volume back into a folder, reorder items and then re-create the volume."
        internal enum BoundBooksCreateAlertDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "bound_books_create_alert_description" }
        }

        /// 🇺🇸 English: "Create a volume"
        internal enum BoundBooksCreateAlertTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "bound_books_create_alert_title" }
        }

        /// 🇺🇸 English: "Combine into Volume"
        internal enum BoundBooksCreateButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "bound_books_create_button" }
        }

        /// 🇺🇸 English: "New Book Volume"
        internal enum BoundBooksNewTitlePlaceholder {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "bound_books_new_title_placeholder" }
        }

        /// 🇺🇸 English: "Convert to Folder"
        internal enum BoundBooksUndoAlertTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "bound_books_undo_alert_title" }
        }

        /// 🇺🇸 English: "Button free"
        internal enum ButtonFreeTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "button_free_title" }
        }

        /// 🇺🇸 English: "Cancel"
        internal enum CancelButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "cancel_button" }
        }

        /// 🇺🇸 English: "Unable to load books"
        internal enum CarplayLibraryError {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "carplay_library_error" }
        }

        /// 🇺🇸 English: "Chapter duration:"
        internal enum ChapterDurationTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "chapter_duration_title" }
        }

        /// 🇺🇸 English: "Chapter %d"
        internal struct ChapterNumberTitle {
            internal let unnamedParam1: Int

            internal init(_ unnamedParam1: Int) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'chapter_number_title' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "chapter_number_title" }
        }

        /// 🇺🇸 English: "Remaining Chapter Time:"
        internal enum ChapterTimeRemainingTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "chapter_time_remaining_title" }
        }

        /// 🇺🇸 English: "Start: %@ - Duration: %@"
        internal struct ChaptersItemDescription {
            internal let unnamedParam1: String
            internal let unnamedParam2: String

            internal init(_ unnamedParam1: String, _ unnamedParam2: String) {
                self.unnamedParam1 = unnamedParam1
                self.unnamedParam2 = unnamedParam2
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1, self.unnamedParam2)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'chapters_item_description' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "chapters_item_description" }
        }

        /// 🇺🇸 English: "Next Chapter"
        internal enum ChaptersNextTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "chapters_next_title" }
        }

        /// 🇺🇸 English: "Previous Chapter"
        internal enum ChaptersPreviousTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "chapters_previous_title" }
        }

        /// 🇺🇸 English: "Chapters"
        internal enum ChaptersTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "chapters_title" }
        }

        /// 🇺🇸 English: "Choose destination"
        internal enum ChooseDestinationTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "choose_destination_title" }
        }

        /// 🇺🇸 English: "The library couldn't be loaded, the device is out of disk space."
        internal enum CoredataErrorDiskfullDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "coredata_error_diskfull_description" }
        }

        /// 🇺🇸 English: "A migration of the database failed, the library will have to be reinitialized."
        internal enum CoredataErrorMigrationDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "coredata_error_migration_description" }
        }

        /// 🇺🇸 English: "Create"
        internal enum CreateButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "create_button" }
        }

        /// 🇺🇸 English: "Create folder"
        internal enum CreatePlaylistButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "create_playlist_button" }
        }

        /// 🇺🇸 English: "Create a new folder"
        internal enum CreatePlaylistTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "create_playlist_title" }
        }

        /// 🇺🇸 English: "Current Folder"
        internal enum CurrentPlaylistTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "current_playlist_title" }
        }

        /// 🇺🇸 English: "Default"
        internal enum DefaultTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "default_title" }
        }

        /// 🇺🇸 English: "Delete"
        internal enum DeleteButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "delete_button" }
        }

        /// 🇺🇸 English: "Delete completely"
        internal enum DeleteCompletelyButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "delete_completely_button" }
        }

        /// 🇺🇸 English: "Delete folder and files"
        internal enum DeleteDeepButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "delete_deep_button" }
        }

        /// 🇺🇸 English: "This will remove all files inside selected folders as well."
        internal enum DeleteMultipleItemsDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "delete_multiple_items_description" }
        }

        /// 🇺🇸 English (plural case 'other'): "Do you want to delete %d items?"
        internal struct DeleteMultipleItemsTitle {
            internal let unnamedParam1: Int

            internal init(_ unnamedParam1: Int) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'delete_multiple_items_title' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "delete_multiple_items_title" }
        }

        /// 🇺🇸 English: "Delete folder only"
        internal enum DeleteShallowButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "delete_shallow_button" }
        }

        /// 🇺🇸 English: "Do you want to delete “%@”?"
        internal struct DeleteSingleItemTitle {
            internal let unnamedParam1: String

            internal init(_ unnamedParam1: String) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'delete_single_item_title' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "delete_single_item_title" }
        }

        /// 🇺🇸 English: "Deleting only the folder will move all its files back to the Library."
        internal enum DeleteSinglePlaylistDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "delete_single_playlist_description" }
        }

        /// 🇺🇸 English: "Deselect All"
        internal enum DeselectAllTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "deselect_all_title" }
        }

        /// 🇺🇸 English: "Downloading file"
        internal enum DownloadingFileTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "downloading_file_title" }
        }

        /// 🇺🇸 English: "You can also move files here by dragging them on this folder in the Library"
        internal enum EmptyPlaylistDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "empty_playlist_description" }
        }

        /// 🇺🇸 English: "Chapters are empty, please verify the contents of the folder: %@"
        internal struct ErrorEmptyChapters {
            internal let unnamedParam1: String

            internal init(_ unnamedParam1: String) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'error_empty_chapters' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "error_empty_chapters" }
        }

        /// 🇺🇸 English: "Chapters couldn't be loaded from: \n%@"
        internal struct ErrorLoadingChapters {
            internal let unnamedParam1: String

            internal init(_ unnamedParam1: String) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'error_loading_chapters' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "error_loading_chapters" }
        }

        /// 🇺🇸 English: "Error"
        internal enum ErrorTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "error_title" }
        }

        /// 🇺🇸 English: "Excellent tip of"
        internal enum ExcellentTipTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "excellent_tip_title" }
        }

        /// 🇺🇸 English: "Existing Folder"
        internal enum ExistingPlaylistButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "existing_playlist_button" }
        }

        /// 🇺🇸 English: "Share"
        internal enum ExportButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "export_button" }
        }

        /// 🇺🇸 English: "If you're really enjoying BookPlayer, you can leave extra tips to support the app's development further. This will help to keep the lights on and features coming."
        internal enum ExtraTipsDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "extra_tips_description" }
        }

        /// 🇺🇸 English: "This book's file couldn't be loaded. Make sure you're not using files with DRM protection (like .aax files)"
        internal enum FileErrorDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "file_error_description" }
        }

        /// 🇺🇸 English: "File error!"
        internal enum FileErrorTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "file_error_title" }
        }

        /// 🇺🇸 English: "This book's file was removed from your device. Import the file again to play the book"
        internal enum FileMissingDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "file_missing_description" }
        }

        /// 🇺🇸 English: "File missing!"
        internal enum FileMissingTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "file_missing_title" }
        }

        /// 🇺🇸 English (plural case 'other'): "%d Files"
        internal struct FilesTitle {
            internal let unnamedParam1: Int

            internal init(_ unnamedParam1: Int) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'files_title' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "files_title" }
        }

        /// 🇺🇸 English: "Please try again later"
        internal enum GenericRetryDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "generic_retry_description" }
        }

        /// 🇺🇸 English: "Swipe left to rewind"
        internal enum GestureSwipeLeftTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "gesture_swipe_left_title" }
        }

        /// 🇺🇸 English: "Swipe right to skip forward"
        internal enum GestureSwipeRightTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "gesture_swipe_right_title" }
        }

        /// 🇺🇸 English: "Swipe vertically to create bookmark"
        internal enum GestureSwipeVerticallyTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "gesture_swipe_vertically_title" }
        }

        /// 🇺🇸 English: "Tap to play or pause"
        internal enum GestureTapTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "gesture_tap_title" }
        }

        /// 🇺🇸 English: "Changing the app icon wasn't successful. Try again later"
        internal enum IconErrorDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "icon_error_description" }
        }

        /// 🇺🇸 English: "By your friends at BookPlayer"
        internal enum IconsBookplayerCreditDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "icons_bookplayer_credit_description" }
        }

        /// 🇺🇸 English (plural case 'other'): "Import %d files into"
        internal struct ImportAlertTitle {
            internal let unnamedParam1: Int

            internal init(_ unnamedParam1: Int) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'import_alert_title' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "import_alert_title" }
        }

        /// 🇺🇸 English: "Import files"
        internal enum ImportButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "import_button" }
        }

        /// 🇺🇸 English: "You can also add files via AirDrop. Send an audiobook file to your device and select BookPlayer from the list that appears."
        internal enum ImportDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "import_description" }
        }

        /// 🇺🇸 English: "Preparing to import files"
        internal enum ImportPreparingTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "import_preparing_title" }
        }

        /// 🇺🇸 English (plural case 'other'): "Processing %d files"
        internal struct ImportProcessingDescription {
            internal let unnamedParam1: Int

            internal init(_ unnamedParam1: Int) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'import_processing_description' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "import_processing_description" }
        }

        /// 🇺🇸 English: "Transferring files may take a while, please make sure the number of files is complete before proceeding."
        internal enum ImportWarningDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "import_warning_description" }
        }

        /// 🇺🇸 English: "Incredible tip of"
        internal enum IncredibleTipTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "incredible_tip_title" }
        }

        /// 🇺🇸 English: "Invalid URL: %@"
        internal struct InvalidUrlTitle {
            internal let unnamedParam1: String

            internal init(_ unnamedParam1: String) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'invalid_url_title' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "invalid_url_title" }
        }

        /// 🇺🇸 English: "Jump to start"
        internal enum JumpStartTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "jump_start_title" }
        }

        /// 🇺🇸 English: "Kind tip of"
        internal enum KindTipTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "kind_tip_title" }
        }

        /// 🇺🇸 English: "LEARN MORE"
        internal enum LearnMoreTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "learn_more_title" }
        }

        /// 🇺🇸 English: "Add"
        internal enum LibraryAddButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "library_add_button" }
        }

        /// 🇺🇸 English: "Add your first book"
        internal enum LibraryAddTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "library_add_title" }
        }

        /// 🇺🇸 English: "Library"
        internal enum LibraryTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "library_title" }
        }

        /// 🇺🇸 English: "Mark as Finished"
        internal enum MarkFinishedTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "mark_finished_title" }
        }

        /// 🇺🇸 English: "Mark as Unfinished"
        internal enum MarkUnfinishedTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "mark_unfinished_title" }
        }

        /// 🇺🇸 English: "Move to Library"
        internal enum MoveLibraryButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "move_library_button" }
        }

        /// 🇺🇸 English: "Move to folder"
        internal enum MovePlaylistButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "move_playlist_button" }
        }

        /// 🇺🇸 English: "Do you want to move '%@' to '%@'?"
        internal struct MoveSingleItemTitle {
            internal let unnamedParam1: String
            internal let unnamedParam2: String

            internal init(_ unnamedParam1: String, _ unnamedParam2: String) {
                self.unnamedParam1 = unnamedParam1
                self.unnamedParam2 = unnamedParam2
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1, self.unnamedParam2)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'move_single_item_title' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "move_single_item_title" }
        }

        /// 🇺🇸 English: "Move"
        internal enum MoveTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "move_title" }
        }

        /// 🇺🇸 English: "Network Error"
        internal enum NetworkErrorTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "network_error_title" }
        }

        /// 🇺🇸 English: "New Folder"
        internal enum NewPlaylistButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "new_playlist_button" }
        }

        /// 🇺🇸 English: "Note"
        internal enum NoteTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "note_title" }
        }

        /// 🇺🇸 English: "OK"
        internal enum OkButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "ok_button" }
        }

        /// 🇺🇸 English: "Options"
        internal enum OptionsButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "options_button" }
        }

        /// 🇺🇸 English: "Pause"
        internal enum PauseTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "pause_title" }
        }

        /// 🇺🇸 English: "Paused"
        internal enum PausedTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "paused_title" }
        }

        /// 🇺🇸 English: "Play"
        internal enum PlayTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "play_title" }
        }

        /// 🇺🇸 English: "Chapter %d of %d"
        internal struct PlayerChapterDescription {
            internal let unnamedParam1: Int
            internal let unnamedParam2: Int

            internal init(_ unnamedParam1: Int, _ unnamedParam2: Int) {
                self.unnamedParam1 = unnamedParam1
                self.unnamedParam2 = unnamedParam2
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1, self.unnamedParam2)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'player_chapter_description' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "player_chapter_description" }
        }

        /// 🇺🇸 English: "Pause playback"
        internal enum PlayerSleepTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "player_sleep_title" }
        }

        /// 🇺🇸 English: "Set playback speed"
        internal enum PlayerSpeedTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "player_speed_title" }
        }

        /// 🇺🇸 English: "Playing"
        internal enum PlayingTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "playing_title" }
        }

        /// 🇺🇸 English: "Add files"
        internal enum PlaylistAddTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "playlist_add_title" }
        }

        /// 🇺🇸 English: "App Icons"
        internal enum PlusAppIconsTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "plus_app_icons_title" }
        }

        /// 🇺🇸 English: "BookPlayer Plus comes with several app icons, matching the color schemes and your wallpaper"
        internal enum PlusIconsDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "plus_icons_description" }
        }

        /// 🇺🇸 English: "Carefully picked color themes to match your favorite books"
        internal enum PlusThemesDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "plus_themes_description" }
        }

        /// 🇺🇸 English: "%d percent Complete"
        internal struct ProgressCompleteDescription {
            internal let unnamedParam1: Int

            internal init(_ unnamedParam1: Int) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'progress_complete_description' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "progress_complete_description" }
        }

        /// 🇺🇸 English: "Progress"
        internal enum ProgressTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "progress_title" }
        }

        /// 🇺🇸 English: "Purchases restored!"
        internal enum PurchasesRestoredTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "purchases_restored_title" }
        }

        /// 🇺🇸 English: "Recent"
        internal enum RecentTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "recent_title" }
        }

        /// 🇺🇸 English: "Rename"
        internal enum RenameButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "rename_button" }
        }

        /// 🇺🇸 English: "Rename item"
        internal enum RenameTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "rename_title" }
        }

        /// 🇺🇸 English: "Restore"
        internal enum RestoreTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "restore_title" }
        }

        /// 🇺🇸 English: "Screen Gestures"
        internal enum ScreenGesturesTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "screen_gestures_title" }
        }

        /// 🇺🇸 English: "sec"
        internal enum SecondsTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "seconds_title" }
        }

        /// 🇺🇸 English: "Select All"
        internal enum SelectAllTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "select_all_title" }
        }

        /// 🇺🇸 English: "Select Item"
        internal enum SelectItemTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "select_item_title" }
        }

        /// 🇺🇸 English: "Select Folder"
        internal enum SelectPlaylistTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "select_playlist_title" }
        }

        /// 🇺🇸 English: "App Icon"
        internal enum SettingsAppIconTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_app_icon_title" }
        }

        /// 🇺🇸 English: "Appearance"
        internal enum SettingsAppearanceTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_appearance_title" }
        }

        /// 🇺🇸 English: "Prevent the device from locking when on the Player screen."
        internal enum SettingsAutolockDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_autolock_description" }
        }

        /// 🇺🇸 English: "Disable Autolock"
        internal enum SettingsAutolockTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_autolock_title" }
        }

        /// 🇺🇸 English: "After finishing an audiobook, playback will resume with all items in the library, including items in folders."
        internal enum SettingsAutoplayDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_autoplay_description" }
        }

        /// 🇺🇸 English: "Restart finished books"
        internal enum SettingsAutoplayRestartTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_autoplay_restart_title" }
        }

        /// 🇺🇸 English: "AUTOPLAY"
        internal enum SettingsAutoplaySectionTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_autoplay_section_title" }
        }

        /// 🇺🇸 English: "AutoPlay Library"
        internal enum SettingsAutoplayTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_autoplay_title" }
        }

        /// 🇺🇸 English: "Include book files"
        internal enum SettingsBackupFilesTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_backup_files_title" }
        }

        /// 🇺🇸 English: "iCloud Backups"
        internal enum SettingsBackupTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_backup_title" }
        }

        /// 🇺🇸 English: "Doubles the volume.\nUse with caution and care for your hearing."
        internal enum SettingsBoostvolumeDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_boostvolume_description" }
        }

        /// 🇺🇸 English: "Boost Volume"
        internal enum SettingsBoostvolumeTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_boostvolume_title" }
        }

        /// 🇺🇸 English: "Settings"
        internal enum SettingsButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_button" }
        }

        /// 🇺🇸 English: "Use Chapter Context"
        internal enum SettingsChaptercontextTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_chaptercontext_title" }
        }

        /// 🇺🇸 English: "Player Controls"
        internal enum SettingsControlsTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_controls_title" }
        }

        /// 🇺🇸 English: "Credits and Licenses"
        internal enum SettingsCreditsTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_credits_title" }
        }

        /// 🇺🇸 English: "Set speed across all books."
        internal enum SettingsGlobalspeedDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_globalspeed_description" }
        }

        /// 🇺🇸 English: "Global Speed Control"
        internal enum SettingsGlobalspeedTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_globalspeed_title" }
        }

        /// 🇺🇸 English: "Playback Settings"
        internal enum SettingsPlaybackTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_playback_title" }
        }

        /// 🇺🇸 English: "Adjust what the list button in the player screen opens"
        internal enum SettingsPlayerinterfaceListDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_playerinterface_list_description" }
        }

        /// 🇺🇸 English: "Opens"
        internal enum SettingsPlayerinterfaceListTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_playerinterface_list_title" }
        }

        /// 🇺🇸 English: "Only when connected to power"
        internal enum SettingsPowerConnectedTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_power_connected_title" }
        }

        /// 🇺🇸 English: "Toggle between displaying the remaining time, total duration and progress of either the chapter or the book in the player screen"
        internal enum SettingsProgresslabelsDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_progresslabels_description" }
        }

        /// 🇺🇸 English: "Progress Labels"
        internal enum SettingsProgresslabelsTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_progresslabels_title" }
        }

        /// 🇺🇸 English: "Use Remaining Time"
        internal enum SettingsRemainingtimeTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_remainingtime_title" }
        }

        /// 🇺🇸 English: "Use Siri to continue the last played book."
        internal enum SettingsSiriLastplayedDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_siri_lastplayed_description" }
        }

        /// 🇺🇸 English: "Last played book"
        internal enum SettingsSiriLastplayedTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_siri_lastplayed_title" }
        }

        /// 🇺🇸 English: "Sleep Timer"
        internal enum SettingsSiriSleeptimerTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_siri_sleeptimer_title" }
        }

        /// 🇺🇸 English: "SIRI SHORTCUTS"
        internal enum SettingsSiriTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_siri_title" }
        }

        /// 🇺🇸 English: "Adjust the amount skipped when using the buttons in the Player or Control Center."
        internal enum SettingsSkipDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_skip_description" }
        }

        /// 🇺🇸 English: "Forward"
        internal enum SettingsSkipForwardTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_skip_forward_title" }
        }

        /// 🇺🇸 English: "Rewind"
        internal enum SettingsSkipRewindTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_skip_rewind_title" }
        }

        /// 🇺🇸 English: "SKIP INTERVALS"
        internal enum SettingsSkipTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_skip_title" }
        }

        /// 🇺🇸 English: "Rewind 30 seconds after being paused for 10 minutes."
        internal enum SettingsSmartrewindDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_smartrewind_description" }
        }

        /// 🇺🇸 English: "Smart Rewind"
        internal enum SettingsSmartrewindTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_smartrewind_title" }
        }

        /// 🇺🇸 English: "Manage your files"
        internal enum SettingsStorageDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_storage_description" }
        }

        /// 🇺🇸 English: "Storage Management"
        internal enum SettingsStorageTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_storage_title" }
        }

        /// 🇺🇸 English: "Copy information to clipboard"
        internal enum SettingsSupportComposeCopy {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_support_compose_copy" }
        }

        /// 🇺🇸 English: "You need to set up an email account in your device settings to use this.\n\nPlease mail us at"
        internal enum SettingsSupportComposeDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_support_compose_description" }
        }

        /// 🇺🇸 English: "Unable to compose email"
        internal enum SettingsSupportComposeTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_support_compose_title" }
        }

        /// 🇺🇸 English: "Send us an email"
        internal enum SettingsSupportEmailTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_support_email_title" }
        }

        /// 🇺🇸 English: "Open new issues for your feature requests and errors"
        internal enum SettingsSupportProjectDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_support_project_description" }
        }

        /// 🇺🇸 English: "View project on Github"
        internal enum SettingsSupportProjectTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_support_project_title" }
        }

        /// 🇺🇸 English: "SUPPORT"
        internal enum SettingsSupportTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_support_title" }
        }

        /// 🇺🇸 English: "Select the dark variation of a theme if the screen brightness falls below the set threshold."
        internal enum SettingsThemeAutobrightness {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_theme_autobrightness" }
        }

        /// 🇺🇸 English: "Theme"
        internal enum SettingsThemeTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_theme_title" }
        }

        /// 🇺🇸 English: "Tip Jar"
        internal enum SettingsTipJarTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_tip_jar_title" }
        }

        /// 🇺🇸 English: "Settings"
        internal enum SettingsTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "settings_title" }
        }

        /// 🇺🇸 English: "Continue last played book"
        internal enum SiriActivityTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "siri_activity_title" }
        }

        /// 🇺🇸 English: "Siri Shortcuts are available on iOS 12 and above"
        internal enum SiriAlertDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "siri_alert_description" }
        }

        /// 🇺🇸 English: "Continue my book"
        internal enum SiriInvocationPhrase {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "siri_invocation_phrase" }
        }

        /// 🇺🇸 English: "Skipped back"
        internal enum SkippedBackTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "skipped_back_title" }
        }

        /// 🇺🇸 English: "Skipped forward"
        internal enum SkippedForwardTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "skipped_forward_title" }
        }

        /// 🇺🇸 English: "Sleeping when the chapter ends"
        internal enum SleepAlertDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "sleep_alert_description" }
        }

        /// 🇺🇸 English: "End of current chapter"
        internal enum SleepChapterOptionTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "sleep_chapter_option_title" }
        }

        /// 🇺🇸 English: "In %@"
        internal struct SleepIntervalTitle {
            internal let unnamedParam1: String

            internal init(_ unnamedParam1: String) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'sleep_interval_title' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "sleep_interval_title" }
        }

        /// 🇺🇸 English: "Off"
        internal enum SleepOffTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "sleep_off_title" }
        }

        /// 🇺🇸 English: "%@ remaining until sleep"
        internal struct SleepRemainingTitle {
            internal let unnamedParam1: String

            internal init(_ unnamedParam1: String) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'sleep_remaining_title' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "sleep_remaining_title" }
        }

        /// 🇺🇸 English: "Sleeping in %@"
        internal struct SleepTimeDescription {
            internal let unnamedParam1: String

            internal init(_ unnamedParam1: String) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'sleep_time_description' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "sleep_time_description" }
        }

        /// 🇺🇸 English: "Custom sleep timer"
        internal enum SleeptimerCustomAlertTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "sleeptimer_custom_alert_title" }
        }

        /// 🇺🇸 English: "Custom"
        internal enum SleeptimerOptionCustom {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "sleeptimer_option_custom" }
        }

        /// 🇺🇸 English: "Original File Name"
        internal enum SortFilenameButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "sort_filename_button" }
        }

        /// 🇺🇸 English: "Sort Files By"
        internal enum SortFilesTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "sort_files_title" }
        }

        /// 🇺🇸 English: "Most Recent"
        internal enum SortMostRecentButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "sort_most_recent_button" }
        }

        /// 🇺🇸 English: "Reverse Order"
        internal enum SortReversedButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "sort_reversed_button" }
        }

        /// 🇺🇸 English: "Sort Items by"
        internal enum SortTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "sort_title" }
        }

        /// 🇺🇸 English: "speed"
        internal enum SpeedTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "speed_title" }
        }

        /// 🇺🇸 English: "The selected file was a duplicate, the existing file is located at: %@"
        internal struct StorageDuplicateItemDescription {
            internal let unnamedParam1: String

            internal init(_ unnamedParam1: String) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'storage_duplicate_item_description' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "storage_duplicate_item_description" }
        }

        /// 🇺🇸 English: "Duplicate"
        internal enum StorageDuplicateItemTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "storage_duplicate_item_title" }
        }

        /// 🇺🇸 English: "Fix All"
        internal enum StorageFixAllTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "storage_fix_all_title" }
        }

        /// 🇺🇸 English: "Fix"
        internal enum StorageFixFileButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "storage_fix_file_button" }
        }

        /// 🇺🇸 English: "The book item is missing, if the corresponding item cannot be found, a new one will be created"
        internal enum StorageFixFileDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "storage_fix_file_description" }
        }

        /// 🇺🇸 English: "The link between the files and the digital book items are missing, if the corresponding item cannot be found for each file, a new one will be created"
        internal enum StorageFixFilesDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "storage_fix_files_description" }
        }

        /// 🇺🇸 English: "Total space used"
        internal enum StorageTotalTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "storage_total_title" }
        }

        /// 🇺🇸 English: "Get BookPlayer Plus to support future development and get extra themes and app icons"
        internal enum SupportBookplayerDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "support_bookplayer_description" }
        }

        /// 🇺🇸 English: "Support BookPlayer"
        internal enum SupportBookplayerTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "support_bookplayer_title" }
        }

        /// 🇺🇸 English: "Support us"
        internal enum SupportUsTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "support_us_title" }
        }

        /// 🇺🇸 English: "You are amazing!"
        internal enum ThanksAmazingTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "thanks_amazing_title" }
        }

        /// 🇺🇸 English: "Thanks for your support!"
        internal enum ThanksTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "thanks_title" }
        }

        /// 🇺🇸 English: "Always use dark variation"
        internal enum ThemeDarkTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "theme_dark_title" }
        }

        /// 🇺🇸 English: "Switch automatically"
        internal enum ThemeSwitchTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "theme_switch_title" }
        }

        /// 🇺🇸 English: "Use System Mode"
        internal enum ThemeSystemTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "theme_system_title" }
        }

        /// 🇺🇸 English: "THEMES"
        internal enum ThemesCapsTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "themes_caps_title" }
        }

        /// 🇺🇸 English: "Themes"
        internal enum ThemesTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "themes_title" }
        }

        /// 🇺🇸 English: "You haven't tipped us yet"
        internal enum TipMissingTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "tip_missing_title" }
        }

        /// 🇺🇸 English: "Title"
        internal enum TitleButton {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "title_button" }
        }

        /// 🇺🇸 English: "%@ by %@, chapter %@"
        internal struct VoiceoverBookChapter {
            internal let unnamedParam1: String
            internal let unnamedParam2: String
            internal let unnamedParam3: String

            internal init(_ unnamedParam1: String, _ unnamedParam2: String, _ unnamedParam3: String) {
                self.unnamedParam1 = unnamedParam1
                self.unnamedParam2 = unnamedParam2
                self.unnamedParam3 = unnamedParam3
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1, self.unnamedParam2, self.unnamedParam3)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'voiceover_book_chapter' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "voiceover_book_chapter" }
        }

        /// 🇺🇸 English: "%@ by %@"
        internal struct VoiceoverBookInfo {
            internal let unnamedParam1: String
            internal let unnamedParam2: String

            internal init(_ unnamedParam1: String, _ unnamedParam2: String) {
                self.unnamedParam1 = unnamedParam1
                self.unnamedParam2 = unnamedParam2
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1, self.unnamedParam2)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'voiceover_book_info' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "voiceover_book_info" }
        }

        /// 🇺🇸 English: "%@ by %@, %d percent completed"
        internal struct VoiceoverBookProgress {
            internal let unnamedParam1: String
            internal let unnamedParam2: String
            internal let unnamedParam3: Int

            internal init(_ unnamedParam1: String, _ unnamedParam2: String, _ unnamedParam3: Int) {
                self.unnamedParam1 = unnamedParam1
                self.unnamedParam2 = unnamedParam2
                self.unnamedParam3 = unnamedParam3
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1, self.unnamedParam2, self.unnamedParam3)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'voiceover_book_progress' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "voiceover_book_progress" }
        }

        /// 🇺🇸 English: "%@, Volume, %d percent Completed"
        internal struct VoiceoverBoundBooksProgress {
            internal let unnamedParam1: String
            internal let unnamedParam2: Int

            internal init(_ unnamedParam1: String, _ unnamedParam2: Int) {
                self.unnamedParam1 = unnamedParam1
                self.unnamedParam2 = unnamedParam2
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1, self.unnamedParam2)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'voiceover_bound_books_progress' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "voiceover_bound_books_progress" }
        }

        /// 🇺🇸 English: "Current Chapter Time: %@"
        internal struct VoiceoverChapterTimeTitle {
            internal let unnamedParam1: String

            internal init(_ unnamedParam1: String) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'voiceover_chapter_time_title' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "voiceover_chapter_time_title" }
        }

        /// 🇺🇸 English: "Continue Playback"
        internal enum VoiceoverContinuePlaybackTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "voiceover_continue_playback_title" }
        }

        /// 🇺🇸 English: "Currently playing %@ by %@"
        internal struct VoiceoverCurrentlyPlayingTitle {
            internal let unnamedParam1: String
            internal let unnamedParam2: String

            internal init(_ unnamedParam1: String, _ unnamedParam2: String) {
                self.unnamedParam1 = unnamedParam1
                self.unnamedParam2 = unnamedParam2
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1, self.unnamedParam2)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'voiceover_currently_playing_title' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "voiceover_currently_playing_title" }
        }

        /// 🇺🇸 English: "Set default speed"
        internal enum VoiceoverDefaultSpeedTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "voiceover_default_speed_title" }
        }

        /// 🇺🇸 English: "Dismiss Player"
        internal enum VoiceoverDismissPlayerTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "voiceover_dismiss_player_title" }
        }

        /// 🇺🇸 English: "Fast Forward %@"
        internal struct VoiceoverForwardTime {
            internal let unnamedParam1: String

            internal init(_ unnamedParam1: String) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'voiceover_forward_time' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "voiceover_forward_time" }
        }

        /// 🇺🇸 English: "Miniplayer. Tap to show the Player"
        internal enum VoiceoverMiniplayerHint {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "voiceover_miniplayer_hint" }
        }

        /// 🇺🇸 English: "No Author"
        internal enum VoiceoverNoAuthor {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "voiceover_no_author" }
        }

        /// 🇺🇸 English: "No Volume Title"
        internal enum VoiceoverNoBoundBooksTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "voiceover_no_bound_books_title" }
        }

        /// 🇺🇸 English: "No File Subtitle"
        internal enum VoiceoverNoFileSubtitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "voiceover_no_file_subtitle" }
        }

        /// 🇺🇸 English: "No File Title"
        internal enum VoiceoverNoFileTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "voiceover_no_file_title" }
        }

        /// 🇺🇸 English: "No Folder Title"
        internal enum VoiceoverNoPlaylistTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "voiceover_no_playlist_title" }
        }

        /// 🇺🇸 English: "No Title"
        internal enum VoiceoverNoTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "voiceover_no_title" }
        }

        /// 🇺🇸 English: "%@, Folder, %d percent completed"
        internal struct VoiceoverPlaylistProgress {
            internal let unnamedParam1: String
            internal let unnamedParam2: Int

            internal init(_ unnamedParam1: String, _ unnamedParam2: Int) {
                self.unnamedParam1 = unnamedParam1
                self.unnamedParam2 = unnamedParam2
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1, self.unnamedParam2)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'voiceover_playlist_progress' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "voiceover_playlist_progress" }
        }

        /// 🇺🇸 English: "Rewind %@"
        internal struct VoiceoverRewindTime {
            internal let unnamedParam1: String

            internal init(_ unnamedParam1: String) {
                self.unnamedParam1 = unnamedParam1
            }

            /// The translated `String` instance.
            internal var string: String {
                let localizedFormatString = Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable")
                return String.localizedStringWithFormat(localizedFormatString, self.unnamedParam1)
            }

            /// The SwiftUI `LocalizedStringKey` instance.
            @available(*, unavailable, message: "'LocalizedStringKey' support requires the translation key 'voiceover_rewind_time' to end with named parameters like in 'User.Description(username: %@, birthYear: %d)'")
            internal var locStringKey: LocalizedStringKey { fatalError() }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal var tableLookupKey: String { "voiceover_rewind_time" }
        }

        /// 🇺🇸 English: "Unknown author"
        internal enum VoiceoverUnknownAuthor {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "voiceover_unknown_author" }
        }

        /// 🇺🇸 English: "Unknown title"
        internal enum VoiceoverUnknownTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "voiceover_unknown_title" }
        }

        /// 🇺🇸 English: "There's a problem connecting to your phone, please try again later"
        internal enum WatchappConnectErrorDescription {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "watchapp_connect_error_description" }
        }

        /// 🇺🇸 English: "Connectivity Error"
        internal enum WatchappConnectErrorTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "watchapp_connect_error_title" }
        }

        /// 🇺🇸 English: "Last Played"
        internal enum WatchappLastPlayedTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "watchapp_last_played_title" }
        }

        /// 🇺🇸 English: "Refresh data"
        internal enum WatchappRefreshDataTitle {
            /// The translated `String` instance.
            internal static var string: String { Bundle.main.localizedString(forKey: self.tableLookupKey, value: nil, table: "Localizable") }

            /// The SwiftUI `LocalizedStringKey` instance.
            internal static var locStringKey: LocalizedStringKey { LocalizedStringKey(self.tableLookupKey) }

            /// The lookup key in the translation table (= the key in the `.strings` or `.stringsdict` file).
            internal static var tableLookupKey: String { "watchapp_refresh_data_title" }
        }
    }
}
