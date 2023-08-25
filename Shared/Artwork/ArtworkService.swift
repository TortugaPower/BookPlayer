//
//  ArtworkService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 23/2/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation
import Kingfisher
import UIKit

public class ArtworkService {
  static public var cache: ImageCache {
    let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.ApplicationGroupIdentifier)!
    
    let cache = try! ImageCache(name: "BookPlayer", cacheDirectoryURL: url)
    cache.diskStorage.config.expiration = .never
    
    return cache
  }
  
  static private var manager: KingfisherManager {
    return KingfisherManager(downloader: .default, cache: ArtworkService.cache)
  }
  
  static let baseDefaultColor = UIColor(hex: "#5FBFD5").rgbColor()!
  static let leftLuminanceGradientOffset: CGFloat = -27.779
  static let leftChromaGradientOffset: CGFloat = 12.363
  static let leftHueGradientOffset: CGFloat = 29.722
  
  static let rightLuminanceGradientOffset: CGFloat = -30.874
  static let rightChromaGradientOffset: CGFloat = 19.337
  static let rightHueGradientOffset: CGFloat = 38.85
  
  public class func retrieveImageFromCache(for relativePath: String, completionHandler: @escaping (Result<RetrieveImageResult, KingfisherError>) -> Void) {
    _ = self.manager.retrieveImage(
      with: .provider(self.getArtworkProvider(for: relativePath)),
      options: [.targetCache(Self.cache)],
      completionHandler: completionHandler
    )
  }
  
  public class func getCachedImageURL(for relativePath: String) -> URL {
    let path = self.cache.cachePath(forKey: relativePath)
    
    return URL(fileURLWithPath: path)
  }
  
  public class func isCached(relativePath: String) -> Bool {
    return self.cache.isCached(forKey: relativePath)
  }
  
  public class func removeCache(for relativePath: String) async {
    await withCheckedContinuation { continuation in
      cache.removeImage(forKey: relativePath) {
        continuation.resume()
      }
    }
  }
  
  public class func removeCache(for relativePath: String) {
    self.cache.removeImage(forKey: relativePath)
  }
  
  public class func storeInCache(_ data: Data, for relativePath: String, completionHandler: (() -> Void)? = nil) {
    self.cache.storeToDisk(data, forKey: relativePath) { _ in
      completionHandler?()
    }
  }
  
  public class func storeInCache(_ data: Data, for relativePath: String) async {
    await withCheckedContinuation { continuation in
      cache.storeToDisk(data, forKey: relativePath) { _ in
        continuation.resume()
      }
    }
  }
  
  public class func getArtworkProvider(
    for relativePath: String,
    remoteURL: URL? = nil
  ) -> AVAudioAssetImageDataProvider {
    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(relativePath)
    
    return AVAudioAssetImageDataProvider(fileURL: fileURL, remoteURL: remoteURL, cacheKey: relativePath)
  }
  
#if os(iOS)
  public class func generateDefaultArtwork(from color: UIColor?, with size: CGSize = CGSize(width: 50, height: 50)) -> UIImage? {
    guard Thread.isMainThread else { return nil }
    
    let baseColorLCH = self.getLCHColor(from: color)
    
    let blankspace = UIView()
    
    let stackView = UIStackView(arrangedSubviews: [blankspace])
    stackView.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    stackView.axis = .vertical
    stackView.backgroundColor = baseColorLCH.toRGB().color()
    stackView.spacing = 2
    
    let leftGradientLayer = CAGradientLayer()
    leftGradientLayer.frame = stackView.frame
    leftGradientLayer.type = .radial
    leftGradientLayer.startPoint = CGPoint(x: 0, y: 0)
    leftGradientLayer.endPoint = CGPoint(x: 1, y: 1)
    let rightGradientLayer = CAGradientLayer()
    rightGradientLayer.frame = stackView.frame
    rightGradientLayer.type = .radial
    rightGradientLayer.startPoint = CGPoint(x: 1, y: 0)
    rightGradientLayer.endPoint = CGPoint(x: 0, y: 1)
    
    leftGradientLayer.colors = self.getLeftGradiants(for: baseColorLCH)
    rightGradientLayer.colors = self.getRightGradiants(for: baseColorLCH)
    
    stackView.layer.insertSublayer(leftGradientLayer, at: 0)
    stackView.layer.insertSublayer(rightGradientLayer, at: 0)
    
    return self.image(with: stackView)
  }
#endif
  
  public class func getLCHColor(from color: UIColor?) -> LCHColor {
    let baseColorLCH: LCHColor
    if let color = color,
       let rgbColor = color.rgbColor() {
      baseColorLCH = rgbColor.toLCH()
    } else {
      baseColorLCH = self.baseDefaultColor.toLCH()
    }
    
    return baseColorLCH
  }
  
  public class func getLeftGradiants(for color: UIColor) -> [CGColor] {
    return self.getLeftGradiants(for: self.getLCHColor(from: color))
  }
  
  public class func getLeftGradiants(for baseColorLCH: LCHColor) -> [CGColor] {
    let leftColor = LCHColor(l: baseColorLCH.l + self.leftLuminanceGradientOffset, c: baseColorLCH.c + self.leftChromaGradientOffset, h: baseColorLCH.h + self.leftHueGradientOffset, alpha: baseColorLCH.alpha)
    let leftBlankColor = LCHColor(l: baseColorLCH.l + self.leftLuminanceGradientOffset, c: baseColorLCH.c + self.leftChromaGradientOffset, h: baseColorLCH.h + self.leftHueGradientOffset, alpha: 0)
    
    return [leftColor.toRGB().color().cgColor, leftBlankColor.toRGB().color().cgColor]
  }
  
  public class func getRightGradiants(for color: UIColor) -> [CGColor] {
    return self.getRightGradiants(for: self.getLCHColor(from: color))
  }
  
  public class func getRightGradiants(for baseColorLCH: LCHColor) -> [CGColor] {
    let rightColor = LCHColor(l: baseColorLCH.l + self.rightLuminanceGradientOffset, c: baseColorLCH.c + self.rightChromaGradientOffset, h: baseColorLCH.h + self.rightHueGradientOffset, alpha: baseColorLCH.alpha)
    let rightBlankColor = LCHColor(l: baseColorLCH.l + self.rightLuminanceGradientOffset, c: baseColorLCH.c + self.rightChromaGradientOffset, h: baseColorLCH.h + self.rightHueGradientOffset, alpha: 0)
    
    return [rightColor.toRGB().color().cgColor, rightBlankColor.toRGB().color().cgColor]
  }
  
#if os(iOS)
  public class func image(with view: UIView) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.isOpaque, 0.0)
    defer { UIGraphicsEndImageContext() }
    if let context = UIGraphicsGetCurrentContext() {
      view.layer.render(in: context)
      let image = UIGraphicsGetImageFromCurrentImageContext()
      return image
    }
    return nil
  }
#endif
}
