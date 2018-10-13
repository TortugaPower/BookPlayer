import Foundation

final class BookSortService {

    var books: [Book]

    init(books: [Book]) {
        self.books          = books
    }

    public func perform(filter type: PlayListSortOrder) throws -> [Book] {
        switch type {
        case .metadataTitle:
            let sortedBooks = try sortByMetadata()
            return sortedBooks
        case .fileName:
            return []
//            return sortByTitle()
        }
    }

    private func sortByMetadata() throws -> [Book] {
        let sortedBooks = try books.sorted(by: { (lhs, rhs) -> Bool in
            guard let lhsName = lhs.originalFileName, let rhsName = rhs.originalFileName else {
                throw SortError.missingOriginalFilename
            }
            return lhsName < rhsName
        })
        return sortedBooks
    }

    private func sortByTitle() {

    }
}

enum SortError: Error {
    case missingOriginalFilename
}
