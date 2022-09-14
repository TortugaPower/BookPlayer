import BookPlayerKit
import Foundation

public final class BookSortService {
  public class func sort(_ items: [SimpleLibraryItem], by type: PlayListSortOrder) -> [SimpleLibraryItem] {
    switch type {
    case .fileName:
      return items.sorted { a, b in
        a.originalFileName.localizedStandardCompare(b.originalFileName)
        == ComparisonResult.orderedAscending
      }
    case .metadataTitle:
      return items.sorted { a, b in
        a.title.localizedStandardCompare(b.title)
        == ComparisonResult.orderedAscending
      }
    case .mostRecent:
      return items.sorted { a, b in
        let t1 = a.lastPlayDate ?? Date.distantPast
        let t2 = b.lastPlayDate ?? Date.distantPast
        return t1 > t2
      }
    case .reverseOrder:
      return items.reversed()
    }
  }
}

public enum PlayListSortOrder: String {
  case metadataTitle = "title"
  case fileName = "originalFileName"
  case mostRecent = "lastPlayDate"
  case reverseOrder
}
