import Foundation

public final class BookSortService {
    public static func sort(_ books: NSOrderedSet, by type: PlayListSortOrder) throws -> NSOrderedSet {
        switch type {
        case .metadataTitle:
            let sortedBooks = try BookSortService.sortByTitle(books)
            return sortedBooks
        case .fileName:
            return try BookSortService.sortByFileName(books)
        }
    }

    private static func sortByTitle(_ books: NSOrderedSet) throws -> NSOrderedSet {
        let sortDescriptor = NSSortDescriptor(key: "title", ascending: true)
        let sortedBooks = books.sortedArray(using: [sortDescriptor])
        return NSOrderedSet(array: sortedBooks)
    }

    private static func sortByFileName(_ books: NSOrderedSet) throws -> NSOrderedSet {
        let sortDescriptor = NSSortDescriptor(key: "originalFileName", ascending: true)
        let sortedBooks = books.sortedArray(using: [sortDescriptor])
        return NSOrderedSet(array: sortedBooks)
    }
}

public enum SortError: Error {
    case missingOriginalFilename,
        invalidType
}

public enum PlayListSortOrder {
    case metadataTitle,
        fileName
}

public protocol Sortable {
    func sort(by sortType: PlayListSortOrder) throws
}
