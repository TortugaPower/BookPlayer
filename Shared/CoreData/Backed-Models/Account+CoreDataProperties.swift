//
//  Account+CoreDataProperties.swift
//  BookPlayer
//
//  Created by gianni.carlo on 10/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import CoreData

extension Account {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<Account> {
    return NSFetchRequest<Account>(entityName: "Account")
  }

  @nonobjc public class func create(in context: NSManagedObjectContext) -> Account {
    // swiftlint:disable:next force_cast
    return NSEntityDescription.insertNewObject(forEntityName: "Account", into: context) as! Account
  }

  @NSManaged public var id: String
  @NSManaged public var email: String
  @NSManaged public var hasSubscription: Bool
  @NSManaged public var donationMade: Bool
}
