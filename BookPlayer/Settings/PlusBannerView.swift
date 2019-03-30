//
//  PlusBannerView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/27/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import Themeable
import UIKit

class PlusBannerView: UIView {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var moreButton: UIButton!

    let nibName = "PlusBannerView"
    var contentView: UIView?
    var showPlus: ((UIViewController) -> Void)?

    func loadViewFromNib() -> UIView? {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: nibName, bundle: bundle)
        return nib.instantiate(withOwner: self, options: nil).first as? UIView
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        guard let view = loadViewFromNib() else { return }
        view.frame = self.bounds
        self.addSubview(view)
        self.contentView = view

        setUpTheming()
    }

    @IBAction func showPlus(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Settings", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "PlusNavigationController")

        var topController = UIApplication.shared.keyWindow?.rootViewController

        while let newTopController = topController?.presentedViewController {
            topController = newTopController
        }

        topController?.present(vc, animated: true, completion: nil)
    }
}

extension PlusBannerView: Themeable {
    func applyTheme(_ theme: Theme) {
        self.titleLabel.textColor = theme.primaryColor
        self.detailLabel.textColor = theme.detailColor
        self.moreButton.backgroundColor = theme.highlightColor
        self.backgroundColor = theme.settingsBackgroundColor
    }
}
