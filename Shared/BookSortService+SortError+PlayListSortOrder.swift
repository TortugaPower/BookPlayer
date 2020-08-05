import Foundation

final class BookSortService {
    public class func sort(_ books: NSOrderedSet, by type: PlayListSortOrder) -> NSOrderedSet {
        switch type {
        case .metadataTitle, .fileName:
            let sortDescriptor = self.getSortDescriptor(by: type)
            return self.sort(books, by: type.rawValue, sortDescriptors: [sortDescriptor])
        case .mostRecent:
            let sortDescriptor = self.getSortDescriptor(by: type, ascending: false)
            return self.sort(books, by: type.rawValue, sortDescriptors: [sortDescriptor])
        case .reverseOrder:
            return books.reversed
        }
    }

    /// Get sort descriptor for book sorting
    /// - Parameters:
    ///   - type: Type of sorting to be performed / Sort using attribute key
    ///   - ascending: Ascending / Descending sort descriptor (Default: true)
    /// - Returns: Sort descriptor for the sort order type
    private class func getSortDescriptor(by type: PlayListSortOrder, ascending: Bool = true) -> NSSortDescriptor {
        switch type {
        case .mostRecent:
            return NSSortDescriptor(key: type.rawValue, ascending: ascending, selector: #selector(NSDate.compare(_:)))
        default:
            return NSSortDescriptor(key: type.rawValue, ascending: ascending, selector: #selector(NSString.localizedStandardCompare(_:)))
        }
    }

    private class func sort(_ books: NSOrderedSet, by key: String, sortDescriptors: [NSSortDescriptor] = []) -> NSOrderedSet {
        let sortedBooks = books.sortedArray(using: sortDescriptors)
        return NSOrderedSet(array: sortedBooks)
    }
}

enum SortError: Error {
    case missingOriginalFilename,
        invalidType
}

public enum PlayListSortOrder: String {
    case metadataTitle = "title"
    case fileName = "originalFileName"
    case mostRecent = "lastPlayDate"
    case reverseOrder
}

protocol Sortable {
    func sort(by sortType: PlayListSortOrder)
}
