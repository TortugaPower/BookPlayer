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
    var cachedArtwork: UIImage?

    public func getBookToPlay() -> Book? {
        return nil
    }

    public var progress: Double {
        return 1.0
    }

    public func getArtwork(for theme: Theme?) -> UIImage? {
        if let cachedArtwork = self.cachedArtwork {
            return cachedArtwork
        }

        guard let artworkData = self.artworkData,
              let image = UIImage(data: artworkData as Data) else {
            #if os(iOS)
            self.cachedArtwork = DefaultArtworkFactory.generateArtwork(from: theme?.linkColor)
            #endif

            return self.cachedArtwork
        }

        self.cachedArtwork = image
        return image
    }

    public func info() -> String { return "" }

    public func jumpToStart() {}

    public func markAsFinished(_ flag: Bool) {}

    public func encode(to encoder: Encoder) throws {
        fatalError("LibraryItem is an abstract class, override this function in the subclass")
    }

    public required convenience init(from decoder: Decoder) throws {
        fatalError("LibraryItem is an abstract class, override this function in the subclass")
    }
}
