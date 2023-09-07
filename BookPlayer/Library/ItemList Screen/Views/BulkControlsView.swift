//
//  BulkControlsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/18/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import UIKit

class BulkControlsView: NibLoadableView {
  @IBOutlet weak var editButton: UIButton!
  @IBOutlet weak var moveButton: UIButton!
  @IBOutlet weak var trashButton: UIButton!
  @IBOutlet weak var moreButton: UIButton!

  var onEditTap: (() -> Void)?
  var onMoveTap: (() -> Void)?
  var onDeleteTap: (() -> Void)?
  var onMoreTap: (() -> Void)?

  override func awakeFromNib() {
    super.awakeFromNib()

    self.editButton.accessibilityLabel = "details_title".localized
    self.moveButton.accessibilityLabel = "move_title".localized
    self.trashButton.accessibilityLabel = "delete_button".localized
    self.moreButton.accessibilityLabel = "options_button".localized
  }

  @IBAction func didPressEdit(_ sender: UIButton) {
    self.onEditTap?()
  }

  @IBAction func didPressMove(_ sender: UIButton) {
    self.onMoveTap?()
  }

  @IBAction func didPressDelete(_ sender: UIButton) {
    self.onDeleteTap?()
  }

  @IBAction func didPressMore(_ sender: UIButton) {
    self.onMoreTap?()
  }
}
