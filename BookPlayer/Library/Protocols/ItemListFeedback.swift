//
//  ItemListFeedback.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/11/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Foundation

protocol ItemListFeedback: ItemList {}

extension ItemListFeedback {
    func showLoadView(_ show: Bool, title: String? = nil, subtitle: String? = nil) {}
}
