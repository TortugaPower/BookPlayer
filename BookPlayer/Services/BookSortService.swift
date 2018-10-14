import Foundation

final class BookSortService {

    var books: NSOrderedSet

    init(books: NSOrderedSet) {
        self.books = books
    }

    public func perform(filter type: PlayListSortOrder) throws -> NSOrderedSet {
        switch type {
        case .metadataTitle:
            let sortedBooks = try sortByMetadata()
            return sortedBooks
        case .fileName:
            return []
//            return sortByTitle()
        }
    }

    private func sortByMetadata() throws -> NSOrderedSet {
//        let sortedBooks = try books.sorted(by: { (lhs, rhs) -> Bool in
//            guard let lhsBook = lhs as? Book, let rhsBook = rhs as? Book else {
//                throw SortError.invalidType
//            }
//
//            guard let lhsName = lhsBook.originalFileName, let rhsName = rhsBook.originalFileName else {
//                throw SortError.missingOriginalFilename
//            }
//            return lhsName < rhsName
//        })
//        return sortedBooks
        let sortDescriptor = NSSortDescriptor(key: "originalFileName", ascending: true)
        let sortedBooks = books.sortedArray(using: [sortDescriptor])
        return NSOrderedSet(array: sortedBooks)
//        return sortedBooks.
    }

//    private func sortByTitle() throws -> NSOrderedSet {
//        return try books.sorted(by: { (lhs, rhs) -> Bool in
//            guard let lhsBook = lhs as? Book, let rhsBook = rhs as? Book else {
//                throw SortError.invalidType
//            }
//            return lhs.title < rhs.title
//        })
//    }
}

enum SortError: Error {
    case missingOriginalFilename,
         invalidType
}
