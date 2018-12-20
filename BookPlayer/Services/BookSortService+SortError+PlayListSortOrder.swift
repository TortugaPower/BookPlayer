import Foundation

final class BookSortService {
    public class func sort(_ books: NSOrderedSet, by type: PlayListSortOrder) -> NSOrderedSet {
        switch type {
        case .metadataTitle, .fileName:
            return self.sort(books, by: type.rawValue)
        }
    }

    private class func sort(_ books: NSOrderedSet, by key: String, ascending: Bool = true) -> NSOrderedSet {
        let sortDescriptor = NSSortDescriptor(key: key, ascending: ascending) { (field1, field2) -> ComparisonResult in
            if let string1 = field1 as? String,
                let string2 = field2 as? String {
                return string1.localizedStandardCompare(string2)
            }

            return ascending ? .orderedAscending : .orderedDescending
        }

        let sortedBooks = books.sortedArray(using: [sortDescriptor])
        return NSOrderedSet(array: sortedBooks)
    }
}

enum SortError: Error {
    case missingOriginalFilename,
        invalidType
}

enum PlayListSortOrder: String {
    case metadataTitle = "title"
    case fileName = "originalFileName"
}

protocol Sortable {
    func sort(by sortType: PlayListSortOrder)
}
