//
//  LibraryItem+CoreDataClass.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import Foundation
import CoreData
import UIKit

public class LibraryItem: NSManagedObject {
    var artwork: UIImage {
        if let artworkData = self.artworkData {
            return UIImage(data: artworkData as Data)!
        } else {
            return #imageLiteral(resourceName: "defaultArtwork")
        }
    }
}
