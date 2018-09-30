//
//  Chapter+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 9/21/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Chapter)
public class Chapter: NSManagedObject {
    var end: TimeInterval {
        return start + duration
    }
}
