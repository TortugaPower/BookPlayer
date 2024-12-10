//
//  Account+CoreDataClass.swift
//  BookPlayer
//
//  Created by gianni.carlo on 10/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import CoreData

@objc(Account)
public class Account: NSManagedObject {
  public var hasId: Bool { id.isEmpty == false }
}
