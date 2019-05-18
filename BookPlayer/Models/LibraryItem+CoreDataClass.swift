//
//  LibraryItem+CoreDataClass.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation
import UIKit

public class LibraryItem: NSManagedObject {
    var artwork: UIImage {
        if let cachedArtwork = self.cachedArtwork {
            return cachedArtwork
        }

        guard let artworkData = self.artworkData else {
            return #imageLiteral(resourceName: "defaultArtwork")
        }

        self.cachedArtwork = UIImage(data: artworkData as Data)
        return self.cachedArtwork!
    }

    func info() -> String { return "" }

    var cachedArtwork: UIImage?

    func getBookToPlay() -> Book? {
        return nil
    }

    var progress: Double {
        return 1.0
    }

    func jumpToStart() {}

    func markAsFinished(_ flag: Bool) {}
}
