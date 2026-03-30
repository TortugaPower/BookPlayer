## Purpose

This PR expands the `AudiobookShelf` browsing experience so users are no longer limited to a flat list of titles.

The main goal is to make the existing AudiobookShelf integration feel closer to the server's native browsing capabilities by adding support for browsing by `Series`, `Collections`, `Authors`, and `Narrators`, while preserving the existing book-list and detail flows.

This change also refactors the AudiobookShelf navigation and data flow so the same UI stack can handle:

- top-level AudiobookShelf libraries
- browse categories within a library
- filtered book lists
- collection contents
- existing audiobook detail views

## Bugfix

Not a bugfix branch.

## Related tasks

- Feature request: improve AudiobookShelf browsing beyond a flat title list
- Requested support for:
  - `search`
  - `series`
  - `collections`
  - `authors`
  - `narrators`

## Approach

The general approach was to extend the current AudiobookShelf integration instead of creating a separate parallel flow.

### Navigation and screen model

Added richer AudiobookShelf route/source modeling so a single library screen can represent multiple kinds of content:

- `AudiobookShelfLibraryLevelData`
- `AudiobookShelfLibraryViewSource`
- `AudiobookShelfBrowseCategory`
- `AudiobookShelfItemFilter`

This allows the same `AudiobookShelfLibraryView` / `AudiobookShelfLibraryViewModel` stack to render:

- library list
- browse-category list
- filtered books
- entity lists
- collection contents

### Service/API updates

Extended `AudiobookShelfConnectionService` with support for additional AudiobookShelf endpoints and filtering behavior:

- `fetchFilterData(in:)`
- `fetchCollections(in:)`
- `fetchCollection(id:)`
- `fetchItems(..., filter:)`

The AudiobookShelf integration now uses:

- `/api/libraries`
- `/api/libraries/{id}/filterdata`
- `/api/libraries/{id}/collections`
- `/api/collections/{id}`
- `/api/libraries/{id}/items?filter=...`

### UI updates

Updated the existing AudiobookShelf list/grid flows to support more than just books and libraries by expanding `AudiobookShelfLibraryItem.Kind` to include:

- `browseCategory`
- `series`
- `collection`
- `author`
- `narrator`

The existing row/grid views were reused and adjusted so these new item types can:

- display appropriate placeholder icons
- show subtitles where useful
- navigate correctly
- avoid enabling download-selection behavior for non-book entities

### Search and browsing behavior

The existing search behavior for books remains in place.

New entity/category screens use local filtering where appropriate, while book-library screens continue to use the current AudiobookShelf search endpoint and filtered item fetches.

## Things to be aware of / Things to focus on

- This PR is focused on `AudiobookShelf` audiobook libraries. Podcast-specific browsing was not expanded in the same way.
- The feature relies on AudiobookShelf server metadata being present in `filterdata` and `collections` responses. If a server/library has sparse metadata, some categories may naturally appear empty.
- The implementation intentionally reuses the existing AudiobookShelf screen stack rather than introducing a separate feature-specific UI flow.

Things to review:

- Navigation behavior between libraries, browse categories, filtered books, and details
- Correctness of AudiobookShelf filter encoding in `AudiobookShelfItemFilter.queryValue`
- Behavior of `search`, sorting, and pagination across the new screen sources
- Whether the current UX for single-library auto-navigation is desirable
- Whether collection and entity placeholder artwork behavior is acceptable for a first pass

## Screenshots
