import Foundation

final class BookSortService {

    var books: NSOrderedSet

    init(books: NSOrderedSet) {
        self.books = books
    }

    public func perform(filter type: PlayListSortOrder) throws -> NSOrderedSet {
        switch type {
        case .metadataTitle:
            let sortedBooks = try sortByTitle()
            return sortedBooks
        case .fileName:
            return try sortByFileName()
        }
    }

    private func sortByTitle() throws -> NSOrderedSet {
        let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)
        let sortedBooks = books.sortedArray(using: [sortDescriptor])
        return NSOrderedSet(array: sortedBooks)
    }

    private func sortByFileName() throws -> NSOrderedSet {
        let sortDescriptor = NSSortDescriptor(key: "originalFileName", ascending: true)
        let sortedBooks = books.sortedArray(using: [sortDescriptor])
        return NSOrderedSet(array: sortedBooks)
    }
}

enum SortError: Error {
    case missingOriginalFilename,
         invalidType
}

enum PlayListSortOrder {
    case metadataTitle,
         fileName
}
