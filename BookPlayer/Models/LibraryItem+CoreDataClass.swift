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
    var artworkImage: UIImage {
        if let artwork = self.artwork {
            return UIImage(data: artwork as Data)!
        } else {
            return #imageLiteral(resourceName: "defaultArtwork")
        }
    }
    
    var percentCompletedRounded: Int {
        return Int(self.percentCompleted)
    }
    
    var percentCompletedRoundedString: String {
        return "\(self.percentCompletedRounded)%"
    }
}
