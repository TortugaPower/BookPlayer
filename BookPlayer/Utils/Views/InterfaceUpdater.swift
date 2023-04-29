//
//  InterfaceUpdater.swift
//  BookPlayer
//
//  Created by gianni.carlo on 20/2/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Combine

public typealias InterfaceUpdater<T> = PassthroughSubject<T, Never>
