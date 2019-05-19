//
//  LibraryItem+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation
import UIKit

@objc(LibraryItem)
public class LibraryItem: NSManagedObject, Codable {
    public var artwork: UIImage {
        if let cachedArtwork = self.cachedArtwork {
            return cachedArtwork
        }

        guard let artworkData = self.artworkData else {
            return #imageLiteral(resourceName: "defaultArtwork")
        }

        self.cachedArtwork = UIImage(data: artworkData as Data)
        return self.cachedArtwork!
    }

    public func info() -> String { return "" }

    var cachedArtwork: UIImage?

    public func getBookToPlay() -> Book? {
        return nil
    }

    public var progress: Double {
        return 1.0
    }

    public func jumpToStart() {}

    public func markAsFinished(_ flag: Bool) {}

    public func encode(to encoder: Encoder) throws {
        fatalError("LibraryItem is an abstract class, override this function in the subclass")
    }

    public required convenience init(from decoder: Decoder) throws {
        fatalError("LibraryItem is an abstract class, override this function in the subclass")
    }
}
