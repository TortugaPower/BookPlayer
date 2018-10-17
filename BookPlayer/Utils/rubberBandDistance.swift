//
//  rubberBandDistance.swift
//  BookPlayer
//
//  Created by Florian Pichler on 28.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Foundation
import UIKit

func rubberBandDistance(_ offset: CGFloat, dimension: CGFloat, constant: CGFloat = 0.55) -> CGFloat {
    let result = (constant * abs(offset) * dimension) / (dimension + constant * abs(offset))

    return offset < 0.0 ? -result : result
}
