//
//  ImportCellView.swift
//  BookPlayer
//
//  Created by Florian Pichler on 21.07.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class ImportCellView: UITableViewCell {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!

    var loading: Bool = false

    var remaining: Int = 0 {
        didSet {
            // TODO: This needs to be replaced by Localizable.stringsdict and NSStringPluralRuleType when localizing
            self.titleLabel.text = self.remaining == 1 ? "Processing 1 file" : "Processing \(self.remaining) files"
        }
    }

    var subtitle: String? {
        get {
            return self.subtitleLabel.text
        }
        set {
            self.subtitleLabel.text = newValue
        }
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
