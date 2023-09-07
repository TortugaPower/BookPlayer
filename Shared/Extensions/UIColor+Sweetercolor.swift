//
//  Sweetercolor.swift
//  Sweetercolor
//
//  Created by Jathu Satkunarajah - August 2015 - Toronto
//  Copyright (c) 2015 Jathu Satkunarajah. All rights reserved.
//

// swiftlint:disable identifier_name file_length

import UIKit

extension UIColor {
  /**
   Create a UIColor with a string hex value.

   - parameter hex:     The hex color, i.e. "FF0072" or "#FF0072".
   - parameter alpha:   The opacity of the color, value between [0,1]. Optional. Default: 1
   */
  public convenience init(hex: String, alpha: CGFloat = 1) {
    var hex = hex.replacingOccurrences(of: "#", with: "")

    guard hex.count == 3 || hex.count == 6 else {
      fatalError("Hex characters must be either 3 or 6 characters")
    }

    if hex.count == 3 {
      let tmp = hex
      hex = ""
      for c in tmp {
        hex += String([c, c])
      }
    }

    let scanner = Scanner(string: hex)
    var rgb: UInt64 = 0
    scanner.scanHexInt64(&rgb)

    let R = CGFloat((rgb >> 16) & 0xff) / 255
    let G = CGFloat((rgb >> 8) & 0xff) / 255
    let B = CGFloat(rgb & 0xff) / 255
    self.init(red: R, green: G, blue: B, alpha: alpha)
  }

  /**
   Create a UIColor with a RGB(A) values. The RGB values must *ALL*
   either be between [0, 1] OR [0, 255], do not interchange between either one.

   - parameter r:   Red value between [0, 1] OR [0, 255].
   - parameter g:   Green value between [0, 1] OR [0, 255].
   - parameter b:   Blue value between [0, 1] OR [0, 255].
   - parameter a:   The opacity of the color, value between [0, 1]. Optional. Default: 1
   */
  convenience init(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1) {
    if (r > 1) || (g > 1) || (b > 1) {
      self.init(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
    } else {
      self.init(red: r, green: g, blue: b, alpha: a)
    }
  }

  /**
   Create a UIColor with a HSB(A) values.

   - parameter h:   Hue value between [0, 1] OR [0, 360].
   - parameter s:   Saturation value between [0, 1] OR [0, 100].
   - parameter b:   Brightness value between [0, 1] OR [0, 100].
   - parameter a:   The opacity of the color, value between [0,1]. Optional. Default: 1
   */
  convenience init(h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat = 1) {
    if (h > 1) || (s > 1) || (b > 1) {
      self.init(hue: h / 360, saturation: s / 100, brightness: b / 100, alpha: a)
    } else {
      self.init(hue: h, saturation: s, brightness: b, alpha: a)
    }
  }

  /**
   Return RGB struct
   */
  public func rgbColor() -> RGBColor? {
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var alpha: CGFloat = 0
    if getRed(&r, green: &g, blue: &b, alpha: &alpha) {
      return RGBColor(r: r, g: g, b: b, alpha: alpha)
    } else {
      return nil
    }
  }

  /**
   Return a *true* black color
   */
  class func black() -> UIColor {
    return UIColor(r: 0, g: 0, b: 0, a: 1)
  }

  /**
   Return a white color
   */
  class func white() -> UIColor {
    return UIColor(r: 1, g: 1, b: 1, a: 1)
  }

  /**
   Create a random color.
   */
  class func random() -> UIColor {
    // Random hue
    let H = CGFloat.random(in: 0...360)
    // Limit saturation to [70, 100]
    let S = CGFloat.random(in: 70...100)
    // Limit brightness to [30, 80]
    let B = CGFloat.random(in: 30...80)

    return UIColor(h: H, s: S, b: B, a: 1)
  }

  /**
   Comapre if two colors are equal.

   - parameter color:      A UIColor to compare.
   - parameter strict:     Should the colors have a 1% difference in the values

   - returns: A boolean, true if same (or very similar for strict) and false otherwize

   */
  func isEqual(to color: UIColor, strict: Bool = true) -> Bool {
    if strict {
      return self.isEqual(color)
    } else {
      let RGBA = self.RGBA
      let other = color.RGBA
      let margin = CGFloat(0.01)

      func comp(a: CGFloat, b: CGFloat) -> Bool {
        return abs(b - a) <= (a * margin)
      }

      return comp(a: RGBA[0], b: other[0]) && comp(a: RGBA[1], b: other[1]) && comp(a: RGBA[2], b: other[2]) && comp(a: RGBA[3], b: other[3])
    }
  }

  /**
   Get the red, green, blue and alpha values.

   - returns: An array of four CGFloat numbers from [0, 1] representing RGBA respectively.
   */
  var RGBA: [CGFloat] {
    var R: CGFloat = 0
    var G: CGFloat = 0
    var B: CGFloat = 0
    var A: CGFloat = 0
    self.getRed(&R, green: &G, blue: &B, alpha: &A)
    return [R, G, B, A]
  }

  /**
   Get the 8 bit red, green, blue and alpha values.

   - returns: An array of four CGFloat numbers from [0, 255] representing RGBA respectively.
   */
  var RGBA_8Bit: [CGFloat] {
    let RGBA = self.RGBA
    return [round(RGBA[0] * 255), round(RGBA[1] * 255), round(RGBA[2] * 255), RGBA[3]]
  }

  /**
   Get the hue, saturation, brightness and alpha values.

   - returns: An array of four CGFloat numbers from [0, 255] representing HSBA respectively.
   */
  var HSBA: [CGFloat] {
    var H: CGFloat = 0
    var S: CGFloat = 0
    var B: CGFloat = 0
    var A: CGFloat = 0
    self.getHue(&H, saturation: &S, brightness: &B, alpha: &A)
    return [H, S, B, A]
  }

  /**
   Get the 8 bit hue, saturation, brightness and alpha values.

   - returns: An array of four CGFloat numbers representing HSBA respectively. Ranges: H[0,360], S[0,100], B[0,100], A[0,1]
   */
  var HSBA_8Bit: [CGFloat] {
    let HSBA = self.HSBA
    return [round(HSBA[0] * 360), round(HSBA[1] * 100), round(HSBA[2] * 100), HSBA[3]]
  }

  /**
   Get the CIE XYZ values.

   - returns: An array of three CGFloat numbers representing XYZ respectively.
   */
  var XYZ: [CGFloat] {
    // http://www.easyrgb.com/index.php?X=MATH&H=02#text2

    let RGBA = self.RGBA

    func XYZ_helper(c: CGFloat) -> CGFloat {
      return (c > 0.04045 ? pow((c + 0.055) / 1.055, 2.4) : c / 12.92) * 100
    }

    let R = XYZ_helper(c: RGBA[0])
    let G = XYZ_helper(c: RGBA[1])
    let B = XYZ_helper(c: RGBA[2])

    let X: CGFloat = (R * 0.4124) + (G * 0.3576) + (B * 0.1805)
    let Y: CGFloat = (R * 0.2126) + (G * 0.7152) + (B * 0.0722)
    let Z: CGFloat = (R * 0.0193) + (G * 0.1192) + (B * 0.9505)

    return [X, Y, Z]
  }

  /**
   Get the CIE L*ab values.

   - returns: An array of three CGFloat numbers representing LAB respectively.
   */
  var LAB: [CGFloat] {
    // http://www.easyrgb.com/index.php?X=MATH&H=07#text7

    let XYZ = self.XYZ

    func LAB_helper(c: CGFloat) -> CGFloat {
      return c > 0.008856 ? pow(c, 1 / 3) : ((7.787 * c) + (16 / 116))
    }

    let X: CGFloat = LAB_helper(c: XYZ[0] / 95.047)
    let Y: CGFloat = LAB_helper(c: XYZ[1] / 100.0)
    let Z: CGFloat = LAB_helper(c: XYZ[2] / 108.883)

    let L: CGFloat = (116 * Y) - 16
    let A: CGFloat = 500 * (X - Y)
    let B: CGFloat = 200 * (Y - Z)

    return [L, A, B]
  }

  /**
   Get the relative luminosity value of the color. This follows the W3 specs of luminosity
   to give weight to colors which humans perceive more of.

   - returns: A CGFloat representing the relative luminosity.
   */
  public var luminance: CGFloat {
    // http://www.w3.org/WAI/GL/WCAG20-TECHS/G18.html

    let RGBA = self.RGBA

    func lumHelper(c: CGFloat) -> CGFloat {
      return (c < 0.03928) ? (c / 12.92) : pow((c + 0.055) / 1.055, 2.4)
    }

    return 0.2126 * lumHelper(c: RGBA[0]) + 0.7152 * lumHelper(c: RGBA[1]) + 0.0722 * lumHelper(c: RGBA[2])
  }

  /**
   Determine if the color is dark based on the relative luminosity of the color.

   - returns: A boolean: true if it is dark and false if it is not dark.
   */
  var isDark: Bool {
    return self.luminance < 0.5
  }

  /**
   Determine if the color is light based on the relative luminosity of the color.

   - returns: A boolean: true if it is light and false if it is not light.
   */
  var isLight: Bool {
    return !self.isDark
  }

  /**
   Determine if this colors is darker than the compared color based on the relative luminosity of both colors.

   - parameter than color: A UIColor to compare.

   - returns: A boolean: true if this colors is darker than the compared color and false if otherwise.
   */
  func isDarker(than color: UIColor) -> Bool {
    return self.luminance < color.luminance
  }

  /**
   Determine if this colors is lighter than the compared color based on the relative luminosity of both colors.

   - parameter than color: A UIColor to compare.

   - returns: A boolean: true if this colors is lighter than the compared color and false if otherwise.
   */
  func isLighter(than color: UIColor) -> Bool {
    return !self.isDarker(than: color)
  }

  /**
   Determine if this color is either black or white.

   - returns: A boolean: true if this color is black or white and false otherwise.
   */
  var isBlackOrWhite: Bool {
    let RGBA = self.RGBA
    let isBlack = RGBA[0] < 0.09 && RGBA[1] < 0.09 && RGBA[2] < 0.09
    let isWhite = RGBA[0] > 0.91 && RGBA[1] > 0.91 && RGBA[2] > 0.91

    return isBlack || isWhite
  }

  /**
   Detemine the distance between two colors based on the way humans perceive them.

   - parameter compare color: A UIColor to compare.

   - returns: A CGFloat representing the deltaE
   */
  func CIE94(compare color: UIColor) -> CGFloat {
    // https://en.wikipedia.org/wiki/Color_difference#CIE94

    let k_L: CGFloat = 1
    let k_C: CGFloat = 1
    let k_H: CGFloat = 1
    let k_1: CGFloat = 0.045
    let k_2: CGFloat = 0.015

    let LAB1 = self.LAB
    let L_1 = LAB1[0], a_1 = LAB1[1], b_1 = LAB1[2]

    let LAB2 = color.LAB
    let L_2 = LAB2[0], a_2 = LAB2[1], b_2 = LAB2[2]

    let deltaL: CGFloat = L_1 - L_2
    let deltaA: CGFloat = a_1 - a_2
    let deltaB: CGFloat = b_1 - b_2

    let C_1: CGFloat = sqrt(pow(a_1, 2) + pow(b_1, 2))
    let C_2: CGFloat = sqrt(pow(a_2, 2) + pow(b_2, 2))
    let deltaC_ab: CGFloat = C_1 - C_2

    let deltaH_ab: CGFloat = sqrt(pow(deltaA, 2) + pow(deltaB, 2) - pow(deltaC_ab, 2))

    let s_L: CGFloat = 1
    let s_C: CGFloat = 1 + (k_1 * C_1)
    let s_H: CGFloat = 1 + (k_2 * C_1)

    // Calculate

    let P1: CGFloat = pow(deltaL / (k_L * s_L), 2)
    let P2: CGFloat = pow(deltaC_ab / (k_C * s_C), 2)
    let P3: CGFloat = pow(deltaH_ab / (k_H * s_H), 2)

    return sqrt((P1.isNaN ? 0 : P1) + (P2.isNaN ? 0 : P2) + (P3.isNaN ? 0 : P3))
  }

  /**
   Detemine the distance between two colors based on the way humans perceive them.
   Uses the Sharma 2004 alteration of the CIEDE2000 algorithm.

   - parameter compare color: A UIColor to compare.

   - returns: A CGFloat representing the deltaE
   */
  // swiftlint:disable:next function_body_length
  func CIEDE2000(compare color: UIColor) -> CGFloat {
    // CIEDE2000, Sharma 2004 -> http://www.ece.rochester.edu/~gsharma/ciede2000/ciede2000noteCRNA.pdf

    func rad2deg(r: CGFloat) -> CGFloat {
      return r * CGFloat(180 / Double.pi)
    }

    func deg2rad(d: CGFloat) -> CGFloat {
      return d * CGFloat(Double.pi / 180)
    }

    let k_l = CGFloat(1), k_c = CGFloat(1), k_h = CGFloat(1)

    let LAB1 = self.LAB
    let L_1 = LAB1[0], a_1 = LAB1[1], b_1 = LAB1[2]

    let LAB2 = color.LAB
    let L_2 = LAB2[0], a_2 = LAB2[1], b_2 = LAB2[2]

    let C_1ab = sqrt(pow(a_1, 2) + pow(b_1, 2))
    let C_2ab = sqrt(pow(a_2, 2) + pow(b_2, 2))
    let C_ab = (C_1ab + C_2ab) / 2

    let G = 0.5 * (1 - sqrt(pow(C_ab, 7) / (pow(C_ab, 7) + pow(25, 7))))
    let a_1_p = (1 + G) * a_1
    let a_2_p = (1 + G) * a_2

    let C_1_p = sqrt(pow(a_1_p, 2) + pow(b_1, 2))
    let C_2_p = sqrt(pow(a_2_p, 2) + pow(b_2, 2))

    // Read note 1 (page 23) for clarification on radians to hue degrees
    let h_1_p = (b_1 == 0 && a_1_p == 0) ? 0 : (atan2(b_1, a_1_p) + CGFloat(2 * Double.pi)) * CGFloat(180 / Double.pi)
    let h_2_p = (b_2 == 0 && a_2_p == 0) ? 0 : (atan2(b_2, a_2_p) + CGFloat(2 * Double.pi)) * CGFloat(180 / Double.pi)

    let deltaL_p = L_2 - L_1
    let deltaC_p = C_2_p - C_1_p

    var h_p: CGFloat = 0
    if (C_1_p * C_2_p) == 0 {
      h_p = 0
    } else if abs(h_2_p - h_1_p) <= 180 {
      h_p = h_2_p - h_1_p
    } else if (h_2_p - h_1_p) > 180 {
      h_p = h_2_p - h_1_p - 360
    } else if (h_2_p - h_1_p) < -180 {
      h_p = h_2_p - h_1_p + 360
    }

    let deltaH_p = 2 * sqrt(C_1_p * C_2_p) * sin(deg2rad(d: h_p / 2))

    let L_p = (L_1 + L_2) / 2
    let C_p = (C_1_p + C_2_p) / 2

    var h_p_bar: CGFloat = 0
    if (h_1_p * h_2_p) == 0 {
      h_p_bar = h_1_p + h_2_p
    } else if abs(h_1_p - h_2_p) <= 180 {
      h_p_bar = (h_1_p + h_2_p) / 2
    } else if abs(h_1_p - h_2_p) > 180, (h_1_p + h_2_p) < 360 {
      h_p_bar = (h_1_p + h_2_p + 360) / 2
    } else if abs(h_1_p - h_2_p) > 180, (h_1_p + h_2_p) >= 360 {
      h_p_bar = (h_1_p + h_2_p - 360) / 2
    }

    let T1 = cos(deg2rad(d: h_p_bar - 30))
    let T2 = cos(deg2rad(d: 2 * h_p_bar))
    let T3 = cos(deg2rad(d: (3 * h_p_bar) + 6))
    let T4 = cos(deg2rad(d: (4 * h_p_bar) - 63))
    let T = 1 - rad2deg(r: 0.17 * T1) + rad2deg(r: 0.24 * T2) - rad2deg(r: 0.32 * T3) + rad2deg(r: 0.20 * T4)

    let deltaTheta = 30 * exp(-pow((h_p_bar - 275) / 25, 2))
    let R_c = 2 * sqrt(pow(C_p, 7) / (pow(C_p, 7) + pow(25, 7)))
    let S_l = 1 + ((0.015 * pow(L_p - 50, 2)) / sqrt(20 + pow(L_p - 50, 2)))
    let S_c = 1 + (0.045 * C_p)
    let S_h = 1 + (0.015 * C_p * T)
    let R_t = -sin(deg2rad(d: 2 * deltaTheta)) * R_c

    // Calculate total

    let P1 = deltaL_p / (k_l * S_l)
    let P2 = deltaC_p / (k_c * S_c)
    let P3 = deltaH_p / (k_h * S_h)
    let deltaE = sqrt(pow(P1, 2) + pow(P2, 2) + pow(P3, 2) + (R_t * P2 * P3))

    return deltaE
  }

  /**
   Determine the contrast ratio between two colors.
   A low ratio implies there is a smaller contrast between the two colors.
   A higher ratio implies there is a larger contrast between the two colors.

   - parameter with color: A UIColor to compare.

   - returns: A CGFloat representing the contrast ratio of the two colors.
   */
  func contrastRatio(with color: UIColor) -> CGFloat {
    // http://www.w3.org/WAI/GL/WCAG20-TECHS/G18.html

    let L1 = self.luminance
    let L2 = color.luminance

    if L1 < L2 {
      return (L2 + 0.05) / (L1 + 0.05)
    } else {
      return (L1 + 0.05) / (L2 + 0.05)
    }
  }

  /**
   Determine if two colors are contrasting or not based on the W3 standard.

   - parameter with color:      A UIColor to compare.
   - parameter strict:          A boolean, if true a stricter judgment of contrast ration will be used. Optional. Default: false

   - returns: a boolean, true of the two colors are contrasting, false otherwise.
   */
  func isContrasting(with color: UIColor, strict: Bool = false) -> Bool {
    // http://www.w3.org/TR/2008/REC-WCAG20-20081211/#visual-audio-contrast-contrast

    let ratio = self.contrastRatio(with: color)
    return strict ? (ratio >= 7) : (ratio > 4.5)
  }

  /**
   Get either black or white to contrast against a color.

   - returns: A UIColor, either black or white to contrast against this color.
   */
  var fullContrastColor: UIColor {
    let RGBA = self.RGBA
    let delta = (0.299 * RGBA[0]) + (0.587 * RGBA[1]) + (0.114 * RGBA[2])

    return delta > 0.5 ? UIColor.black() : UIColor.white()
  }

  /**
   Get a clone of this color with a different alpha value.

   - parameter newAlpha: The opacity of the new color, value from [0, 1]

   - returns: A UIColor clone with the new alpha.
   */
  public func withAlpha(newAlpha: CGFloat) -> UIColor {
    return self.withAlphaComponent(newAlpha)
  }

  /**
   Get a new color with a mask overlay blend mode on top of this color.
   This is similar to Photoshop's overlay blend mode.

   - parameter with color: A UIColor to apply as an overlay mask on top.

   - returns: A UIColor with the applied overlay.
   */

  func overlay(with color: UIColor) -> UIColor {
    let mainRGBA = self.RGBA
    let maskRGBA = color.RGBA

    func masker(a: CGFloat, b: CGFloat) -> CGFloat {
      if a < 0.5 {
        return 2 * a * b
      } else {
        return 1 - (2 * (1 - a) * (1 - b))
      }
    }

    return UIColor(r: masker(a: mainRGBA[0], b: maskRGBA[0]),
                   g: masker(a: mainRGBA[1], b: maskRGBA[1]),
                   b: masker(a: mainRGBA[2], b: maskRGBA[2]),
                   a: masker(a: mainRGBA[3], b: maskRGBA[3]))
  }

  /**
   Get a new color if a black overlay was applied.

   - returns: A UIColor with a black overlay.
   */
  var overlayBlack: UIColor {
    return self.overlay(with: UIColor.black())
  }

  /**
   Get a new color if a white overlay was applied.

   - returns: A UIColor with a white overlay.
   */
  var overlayWhite: UIColor {
    return self.overlay(with: UIColor.white())
  }

  /**
   Get a new color with a mask multiply blend mode on top of this color.
   This is similar to Photoshop's multiply blend mode.

   - parameter with color: A UIColor to apply as a multiply mask on top.

   - returns: A UIColor with the applied multiply blend mode.
   */
  func multiply(with color: UIColor) -> UIColor {
    let mainRGBA = self.RGBA
    let maskRGBA = color.RGBA

    return UIColor(r: mainRGBA[0] * maskRGBA[0],
                   g: mainRGBA[1] * maskRGBA[1],
                   b: mainRGBA[2] * maskRGBA[2],
                   a: mainRGBA[3] * maskRGBA[3])
  }

  /**
   Get a new color with a mask screen blend mode on top of this color.
   This is similar to Photoshop's screen blend mode.

   - parameter with color: A UIColor to apply as a screen mask on top.

   - returns: A UIColor with the applied screen blend mode.
   */
  func screen(with color: UIColor) -> UIColor {
    let mainRGBA = self.RGBA
    let maskRGBA = color.RGBA

    func masker(a: CGFloat, b: CGFloat) -> CGFloat {
      return 1 - ((1 - a) * (1 - b))
    }

    return UIColor(r: masker(a: mainRGBA[0], b: maskRGBA[0]),
                   g: masker(a: mainRGBA[1], b: maskRGBA[1]),
                   b: masker(a: mainRGBA[2], b: maskRGBA[2]),
                   a: masker(a: mainRGBA[3], b: maskRGBA[3]))
  }

  // Harmony helper method
  private func harmony(hueIncrement: CGFloat) -> UIColor {
    // http://www.tigercolor.com/color-lab/color-theory/color-harmonies.htm

    let HSBA = self.HSBA_8Bit
    let total = HSBA[0] + hueIncrement
    let newHue = abs(total.truncatingRemainder(dividingBy: 360.0))

    return UIColor(h: newHue, s: HSBA[1], b: HSBA[2], a: HSBA[3])
  }

  /**
   Get the complement of this color on the hue wheel.

   - returns: A complement UIColor.
   */
  var complement: UIColor {
    return self.harmony(hueIncrement: 180)
  }
}

private let RAD_TO_DEG = 180 / CGFloat(Double.pi)

private let LAB_E: CGFloat = 0.008856
private let LAB_16_116: CGFloat = 0.1379310
private let LAB_K_116: CGFloat = 7.787036
private let LAB_X: CGFloat = 0.95047
private let LAB_Y: CGFloat = 1
private let LAB_Z: CGFloat = 1.08883

// MARK: - RGB
public struct RGBColor {
  public let r: CGFloat     // 0..1
  public let g: CGFloat     // 0..1
  public let b: CGFloat     // 0..1
  public let alpha: CGFloat // 0..1

  public init (r: CGFloat, g: CGFloat, b: CGFloat, alpha: CGFloat) {
    self.r = r
    self.g = g
    self.b = b
    self.alpha = alpha
  }

  fileprivate func sRGBCompand(_ v: CGFloat) -> CGFloat {
    let absV = abs(v)
    let out = absV > 0.04045 ? pow((absV + 0.055) / 1.055, 2.4) : absV / 12.92
    return v > 0 ? out : -out
  }

  public func toXYZ() -> XYZColor {
    let R = sRGBCompand(r)
    let G = sRGBCompand(g)
    let B = sRGBCompand(b)
    let x: CGFloat = (R * 0.4124564) + (G * 0.3575761) + (B * 0.1804375)
    let y: CGFloat = (R * 0.2126729) + (G * 0.7151522) + (B * 0.0721750)
    let z: CGFloat = (R * 0.0193339) + (G * 0.1191920) + (B * 0.9503041)
    return XYZColor(x: x, y: y, z: z, alpha: alpha)
  }

  public func toLAB() -> LABColor {
    return toXYZ().toLAB()
  }

  public func toLCH() -> LCHColor {
    return toXYZ().toLCH()
  }

  public func color() -> UIColor {
    return UIColor(red: r, green: g, blue: b, alpha: alpha)
  }
}

// MARK: - XYZ
public struct XYZColor {
  public let x: CGFloat     // 0..0.95047
  public let y: CGFloat     // 0..1
  public let z: CGFloat     // 0..1.08883
  public let alpha: CGFloat // 0..1

  public init (x: CGFloat, y: CGFloat, z: CGFloat, alpha: CGFloat) {
    self.x = x
    self.y = y
    self.z = z
    self.alpha = alpha
  }

  fileprivate func sRGBCompand(_ v: CGFloat) -> CGFloat {
    let absV = abs(v)
    let out = absV > 0.0031308 ? 1.055 * pow(absV, 1 / 2.4) - 0.055 : absV * 12.92
    return v > 0 ? out : -out
  }

  public func toRGB() -> RGBColor {
    let r = (x *  3.2404542) + (y * -1.5371385) + (z * -0.4985314)
    let g = (x * -0.9692660) + (y *  1.8760108) + (z *  0.0415560)
    let b = (x *  0.0556434) + (y * -0.2040259) + (z *  1.0572252)
    let R = sRGBCompand(r)
    let G = sRGBCompand(g)
    let B = sRGBCompand(b)
    return RGBColor(r: R, g: G, b: B, alpha: alpha)
  }

  fileprivate func labCompand(_ v: CGFloat) -> CGFloat {
    return v > LAB_E ? pow(v, 1.0 / 3.0) : (LAB_K_116 * v) + LAB_16_116
  }

  public func toLAB() -> LABColor {
    let fx = labCompand(x / LAB_X)
    let fy = labCompand(y / LAB_Y)
    let fz = labCompand(z / LAB_Z)
    return LABColor(
      l: 116 * fy - 16,
      a: 500 * (fx - fy),
      b: 200 * (fy - fz),
      alpha: alpha
    )
  }

  public func toLCH() -> LCHColor {
    return toLAB().toLCH()
  }
}

// MARK: - LAB
public struct LABColor {
  public let l: CGFloat     //    0..100
  public let a: CGFloat     // -128..128
  public let b: CGFloat     // -128..128
  public let alpha: CGFloat //    0..1

  public init (l: CGFloat, a: CGFloat, b: CGFloat, alpha: CGFloat) {
    self.l = l
    self.a = a
    self.b = b
    self.alpha = alpha
  }

  fileprivate func xyzCompand(_ v: CGFloat) -> CGFloat {
    let v3 = v * v * v
    return v3 > LAB_E ? v3 : (v - LAB_16_116) / LAB_K_116
  }

  public func toXYZ() -> XYZColor {
    let y = (l + 16) / 116
    let x = y + (a / 500)
    let z = y - (b / 200)
    return XYZColor(
      x: xyzCompand(x) * LAB_X,
      y: xyzCompand(y) * LAB_Y,
      z: xyzCompand(z) * LAB_Z,
      alpha: alpha
    )
  }

  public func toLCH() -> LCHColor {
    let c = sqrt(a * a + b * b)
    let angle = atan2(b, a) * RAD_TO_DEG
    let h = angle < 0 ? angle + 360 : angle
    return LCHColor(l: l, c: c, h: h, alpha: alpha)
  }

  public func toRGB() -> RGBColor {
    return toXYZ().toRGB()
  }
}

// MARK: - LCH
public struct LCHColor {
  public let l: CGFloat     // 0..100
  public let c: CGFloat     // 0..128
  public let h: CGFloat     // 0..360
  public let alpha: CGFloat // 0..1

  public init (l: CGFloat, c: CGFloat, h: CGFloat, alpha: CGFloat) {
    self.l = l
    self.c = c
    self.h = h
    self.alpha = alpha
  }

  public func toLAB() -> LABColor {
    let rad = h / RAD_TO_DEG
    let a = cos(rad) * c
    let b = sin(rad) * c
    return LABColor(l: l, a: a, b: b, alpha: alpha)
  }

  public func toXYZ() -> XYZColor {
    return toLAB().toXYZ()
  }

  public func toRGB() -> RGBColor {
    return toXYZ().toRGB()
  }
}

// swiftlint:enable identifier_name file_length
