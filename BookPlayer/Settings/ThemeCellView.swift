//
//  ThemeCellView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/18/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import Themeable
import UIKit

class ThemeCellView: UITableViewCell {
    @IBOutlet weak var showCaseView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var plusImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()

        self.showCaseView.layer.shadowColor = UIColor.black.cgColor
        self.showCaseView.layer.shadowOffset = CGSize(width: 0, height: 0)
        self.showCaseView.layer.shadowOpacity = 0.4
        self.showCaseView.layer.shadowRadius = 1.0

        setUpTheming()
    }

    func setupShowCaseView(for theme: Theme) {
        self.showCaseView.layer.sublayers = nil
        self.addLayer(to: self.showCaseView, mask: "themeColorBackgroundMask", backgroundColor: theme.defaultBackgroundColor)
        self.addLayer(to: self.showCaseView, mask: "themeColorAccentMask", backgroundColor: theme.defaultAccentColor)
        self.addLayer(to: self.showCaseView, mask: "themeColorPrimaryMask", backgroundColor: theme.defaultPrimaryColor)
        self.addLayer(to: self.showCaseView, mask: "themeColorSecondaryMask", backgroundColor: theme.defaultSecondaryColor)
    }

    private func addLayer(to view: UIView, mask name: String, backgroundColor: UIColor) {
        guard let image = UIImage(named: name),
            let maskImage = image.cgImage else { return }

        let layer = CALayer()
        layer.frame = view.bounds
        layer.backgroundColor = backgroundColor.cgColor

        let mask = CALayer(layer: maskImage)
        mask.frame = view.bounds
        mask.contents = maskImage
        layer.mask = mask

        view.layer.addSublayer(layer)
    }
}

extension ThemeCellView: Themeable {
    func applyTheme(_ theme: Theme) {
        self.titleLabel?.textColor = theme.primaryColor
        self.backgroundColor = theme.backgroundColor
    }
}
