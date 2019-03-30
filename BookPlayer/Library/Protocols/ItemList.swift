//
//  ItemList.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/10/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

protocol ItemList {
    var library: Library! { get set }
    var items: [LibraryItem] { get }
    var tableView: UITableView! { get }

    func reloadData()
}
