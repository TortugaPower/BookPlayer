//
//  limitPanAngle.swift
//  BookPlayer
//
//  Created by Florian Pichler on 07.05.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Foundation
import UIKit

enum PanAngleComparator {
    case lessThan
    case greaterThan
}

func limitPanAngle(_ gestureRecognizer: UIPanGestureRecognizer, degreesOfFreedom: CGFloat = 45.0, comparator: PanAngleComparator = .lessThan) -> Bool {
    let velocity: CGPoint = gestureRecognizer.velocity(in: gestureRecognizer.view)
    let degree: CGFloat = atan(velocity.y / velocity.x) * 180 / CGFloat.pi

    switch comparator {
    case .lessThan:
        return abs(degree) < degreesOfFreedom
    case .greaterThan:
        return abs(degree) > degreesOfFreedom
    }
}
