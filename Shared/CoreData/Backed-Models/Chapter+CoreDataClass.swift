//
//  Chapter+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//
//

import AVFoundation
import CoreData
import Foundation

@objc(Chapter)
public class Chapter: NSManagedObject {
  public var end: TimeInterval {
    return start + duration
  }
}
