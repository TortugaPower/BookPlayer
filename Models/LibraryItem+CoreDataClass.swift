//
//  LibraryItem+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 9/21/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
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

    var cachedArtwork: UIImage?

    var isCompleted: Bool {
        return false
    }

    func getBookToPlay() -> Book? {
        return nil
    public func encode(to encoder: Encoder) throws {
        fatalError("LibraryItem is an abstract class, override this function in the subclass")
    }

    public required convenience init(from decoder: Decoder) throws {
        fatalError("LibraryItem is an abstract class, override this function in the subclass")
    }
}
