//
//  LoadingView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/25/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import Themeable
import UIKit

class LoadingView: UIView {
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var separatorView: UIView!

    let nibName = "LoadingView"
    var contentView: UIView?

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
}

extension LoadingView: Themeable {
    func applyTheme(_ theme: Theme) {
        self.backgroundColor = theme.importBackgroundColor
        self.titleLabel.textColor = theme.primaryColor
        self.subtitleLabel.textColor = theme.detailColor
        self.separatorView.backgroundColor = theme.separatorColor
        self.activityIndicator.color = theme.useDarkVariant ? .white : .gray
    }
}
