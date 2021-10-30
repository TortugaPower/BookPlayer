//
//  UIImage+BookPlayer.swift
//  BookPlayer
//
//  Created by Florian Pichler on 28.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

extension UIImage {
    func averageColor() -> UIColor? {
        var bitmap = [UInt8](repeating: 0, count: 4)
        var inputImage: CIImage

        if let ciImage = self.ciImage {
            inputImage = ciImage
        } else if let cgImage = self.cgImage {
            inputImage = CoreImage.CIImage(cgImage: cgImage)
        } else {
            return nil
        }

        // Get average color.
        let context = CIContext()
        let extent = inputImage.extent
        let inputExtent = CIVector(x: extent.origin.x, y: extent.origin.y, z: extent.size.width, w: extent.size.height)

        guard
            let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: inputExtent]),
            let outputImage = filter.outputImage
        else {
            return nil
        }

        let outputExtent = outputImage.extent

        assert(outputExtent.size.width == 1 && outputExtent.size.height == 1)

        // Render to bitmap.
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: CIFormat.RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        // Compute result.
        let result = UIColor(red: CGFloat(bitmap[0]) / 255.0, green: CGFloat(bitmap[1]) / 255.0, blue: CGFloat(bitmap[2]) / 255.0, alpha: CGFloat(bitmap[3]) / 255.0)

        return result
    }

    func imageWith(newSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let image = renderer.image { _ in
            self.draw(in: CGRect(origin: CGPoint.zero, size: newSize))
        }

        return image
    }

    func addLayerMask(_ name: String) -> UIImage {
        guard
            let image = UIImage(named: name),
            let currentImage = self.cgImage,
            let maskImageReference = image.cgImage,
            let provider = maskImageReference.dataProvider,
            let imageMask = CGImage(maskWidth: maskImageReference.width,
                                    height: maskImageReference.height,
                                    bitsPerComponent: maskImageReference.bitsPerComponent,
                                    bitsPerPixel: maskImageReference.bitsPerPixel,
                                    bytesPerRow: maskImageReference.bytesPerRow,
                                    provider: provider,
                                    decode: nil,
                                    shouldInterpolate: false)
        else { return self }

        guard let maskedImage = currentImage.masking(imageMask) else { return self }

        return UIImage(cgImage: maskedImage)
    }
}
