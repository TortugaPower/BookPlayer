//
//  BulkControlsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/18/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import UIKit

class BulkControlsView: UIView {
    @IBOutlet weak var sortButton: UIButton!
    @IBOutlet weak var moveButton: UIButton!
    @IBOutlet weak var trashButton: UIButton!

    var onSortTap: (() -> Void)?
    var onMoveTap: (() -> Void)?
    var onDeleteTap: (() -> Void)?

    let nibName = "BulkControlsView"
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
    }

    @IBAction func didPressSort(_ sender: UIButton) {
        self.onSortTap?()
    }

    @IBAction func didPressMove(_ sender: UIButton) {
        self.onMoveTap?()
    }

    @IBAction func didPressDelete(_ sender: UIButton) {
        self.onDeleteTap?()
    }
}
