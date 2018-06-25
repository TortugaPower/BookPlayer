//
//  UIImage+BookPlayer.swift
//  BookPlayer
//
//  Created by Florian Pichler on 28.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

extension UIImage {
    func averageColor() -> UIColor {
        var bitmap = [UInt8](repeating: 0, count: 4)

        // Get average color.
        let context = CIContext()
        let inputImage: CIImage = ciImage ?? CoreImage.CIImage(cgImage: cgImage!)
        let extent = inputImage.extent
        let inputExtent = CIVector(x: extent.origin.x, y: extent.origin.y, z: extent.size.width, w: extent.size.height)
        let filter = CIFilter(name: "CIAreaAverage", withInputParameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: inputExtent])!
        let outputImage = filter.outputImage!
        let outputExtent = outputImage.extent

        assert(outputExtent.size.width == 1 && outputExtent.size.height == 1)

        // Render to bitmap.
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: kCIFormatRGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        // Compute result.
        let result = UIColor(red: CGFloat(bitmap[0]) / 255.0, green: CGFloat(bitmap[1]) / 255.0, blue: CGFloat(bitmap[2]) / 255.0, alpha: CGFloat(bitmap[3]) / 255.0)

        return result
    }
}
