//
//  PlusViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/20/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Kingfisher
import SafariServices
import RevenueCat
import Themeable
import UIKit

struct Contributor: Decodable {
    var id: Int
    var login: String
    var html_url: String
    var avatar_url: String

    var avatarURL: URL {
        return URL(string: self.avatar_url)!
    }

    var profileURL: URL {
        return URL(string: self.html_url)!
    }
}

class PlusViewController: UIViewController, Storyboarded {
    @IBOutlet weak var scrollContentHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var kindTipButton: UIButton!
    @IBOutlet weak var kindTipButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var kindTipSpinner: UIActivityIndicatorView!

    @IBOutlet weak var excellentTipButton: UIButton!
    @IBOutlet weak var excellentTipButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var excellentTipSpinner: UIActivityIndicatorView!

    @IBOutlet weak var incredibleTipButton: UIButton!
    @IBOutlet weak var incredibleTipButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var incredibleTipSpinner: UIActivityIndicatorView!

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var maintainersViewTopConstraint: NSLayoutConstraint!

    @IBOutlet weak var gianniImageView: UIImageView!
    @IBOutlet weak var pichImageView: UIImageView!

    @IBOutlet var titleLabels: [UILabel]!
    @IBOutlet var detailLabels: [UILabel]!
    @IBOutlet var imageViews: [UIImageView]!

    @IBOutlet var plusViews: [UIView]!
    @IBOutlet weak var tipDescriptionLabel: UILabel!

  var viewModel: PlusViewModel!
  private var disposeBag = Set<AnyCancellable>()

    var loadingBarButton: UIBarButtonItem!
    var restoreBarButton: UIBarButtonItem!

    var kindTipId = "\(Bundle.main.configurationString(for: .bundleIdentifier)).tip.kind"
    var excellentTipId = "\(Bundle.main.configurationString(for: .bundleIdentifier)).tip.excellent"
    var incredibleTipId = "\(Bundle.main.configurationString(for: .bundleIdentifier)).tip.incredible"
    let tipJarSuffix = ".consumable"

    // constants for button animations
    let defaultTipButtonsWidth: CGFloat = 75.0

    // constants for collectionView layout
    let sectionInsets = UIEdgeInsets(top: 0.0, left: 10.0, bottom: 25.0, right: 0.0)
    let cellHeight = 40

    // Maintainers
    let contributorGianni = Contributor(id: 14112819,
                                        login: "GianniCarlo",
                                        html_url: "https://github.com/GianniCarlo",
                                        avatar_url: "https://avatars2.githubusercontent.com/u/14112819?v=4")
    let contributorPichfl = Contributor(id: 194641,
                                        login: "pichfl",
                                        html_url: "https://github.com/pichfl",
                                        avatar_url: "https://avatars2.githubusercontent.com/u/194641?v=4")

    var contributors = [Contributor]() {
        didSet {
            // Resize scroll content height
            let rows = Double(self.contributors.count) / 4
            let collectionheight = CGFloat(Int(rows.rounded(.up)) * self.cellHeight) + self.sectionInsets.bottom

            self.collectionViewHeightConstraint.constant = collectionheight
            self.scrollContentHeightConstraint.constant = collectionheight + self.collectionView.frame.origin.y

            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
                self.collectionView.reloadSections(IndexSet(integer: 0))
            }
        }
    }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.navigationItem.rightBarButtonItem?.title = "restore_title".localized

    self.gianniImageView.kf.setImage(with: self.contributorGianni.avatarURL)
    self.pichImageView.kf.setImage(with: self.contributorPichfl.avatarURL)

    let activityIndicatorView = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.medium)
    activityIndicatorView.startAnimating()
    activityIndicatorView.color = self.themeProvider.currentTheme.useDarkVariant ? .white : .gray
    self.loadingBarButton = UIBarButtonItem(customView: activityIndicatorView)

    if self.viewModel.hasMadeDonation() {
      self.setupTipJarLayout()
    }

    self.setupContributors()
    self.setupLocalizedTipPrices()

    setUpTheming()
  }

    func setupTipJarLayout() {
        for view in self.plusViews {
            view.isHidden = true
        }

        self.navigationItem.title = "settings_tip_jar_title".localized
        self.navigationItem.rightBarButtonItem = nil
        self.tipDescriptionLabel.isHidden = false
        self.maintainersViewTopConstraint.constant = 35

        self.kindTipId += self.tipJarSuffix
        self.excellentTipId += self.tipJarSuffix
        self.incredibleTipId += self.tipJarSuffix
    }

  func setupLocalizedTipPrices() {
    self.showSpinner(true, senders: [self.kindTipButton, self.excellentTipButton, self.incredibleTipButton])

    Purchases.shared.getProducts([self.kindTipId, self.excellentTipId, self.incredibleTipId]) { [weak self] products in
      guard let self = self else { return }

      guard !products.isEmpty else {
        self.showAlert("error_title".localized, message: "network_error_title".localized)
        return
      }

      for product in products {
        if product.productIdentifier.contains(self.kindTipId) {
          self.kindTipButton.setTitle(product.localizedPriceString, for: .normal)
        } else if product.productIdentifier.contains(self.excellentTipId) {
          self.excellentTipButton.setTitle(product.localizedPriceString, for: .normal)
        } else if product.productIdentifier.contains(self.incredibleTipId) {
          self.incredibleTipButton.setTitle(product.localizedPriceString, for: .normal)
        }
      }

      self.showSpinner(false, senders: [self.kindTipButton, self.excellentTipButton, self.incredibleTipButton])
    }
  }

    func setupSpinners() {
        self.kindTipSpinner.stopAnimating()
        self.excellentTipSpinner.stopAnimating()
        self.incredibleTipSpinner.stopAnimating()
    }

    func setupContributors() {
        let layout = UICollectionViewCenterLayout()
        layout.estimatedItemSize = CGSize(width: 45, height: self.cellHeight)
        self.collectionView.collectionViewLayout = layout

        let url = URL(string: "https://api.github.com/repos/TortugaPower/BookPlayer/contributors")!
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                let contributors = try? JSONDecoder().decode([Contributor].self, from: data) else { return }

            DispatchQueue.main.async {
                self.contributors = contributors.filter { (contributor) -> Bool in
                    contributor.id != self.contributorGianni.id && contributor.id != self.contributorPichfl.id
                }
            }
        }

        task.resume()
    }

  @IBAction func close(_ sender: UIBarButtonItem) {
    self.dismiss(animated: true, completion: nil)
  }

  @IBAction func restorePurchases(_ sender: UIBarButtonItem) {
    self.restoreBarButton = self.navigationItem.rightBarButtonItem
    self.navigationItem.rightBarButtonItem = self.loadingBarButton

    Purchases.shared.restorePurchases { [weak self] customerInfo, error in
      guard let self = self else { return }

      self.navigationItem.rightBarButtonItem = self.restoreBarButton

      if let error = error {
        self.showAlert("error_title".localized, message: error.localizedDescription)
        return
      }

      guard let customerInfo = customerInfo else {
        self.showAlert("error_title".localized, message: "network_error_title".localized)
        return
      }

      if customerInfo.nonSubscriptions.isEmpty {
        self.showAlert("tip_missing_title".localized, message: nil)
      } else {
        self.showAlert("purchases_restored_title".localized, message: nil, style: .alert, completion: {
          self.dismiss(animated: true, completion: nil)
        })

        self.view.startConfetti()
        self.viewModel.handleNewDonation()
      }
    }
  }

    @IBAction func showGianniProfile(_ sender: UIButton) {
        self.showProfile(self.contributorGianni.profileURL)
    }

    @IBAction func showPichProfile(_ sender: UIButton) {
        self.showProfile(self.contributorPichfl.profileURL)
    }

    @IBAction func kindTipPressed(_ sender: UIButton) {
        self.requestProduct(self.kindTipId, sender: sender)
    }

    @IBAction func excellentTipPressed(_ sender: UIButton) {
        self.requestProduct(self.excellentTipId, sender: sender)
    }

    @IBAction func incredibleTipPressed(_ sender: UIButton) {
        self.requestProduct(self.incredibleTipId, sender: sender)
    }

    func hideAllSpinners() {
        self.showSpinner(false, senders: [self.kindTipButton, self.excellentTipButton, self.incredibleTipButton])
    }

    func showSpinner(_ flag: Bool, senders: [UIButton]) {
        for sender in senders {
            var spinner: UIActivityIndicatorView!
            var widthConstraint: NSLayoutConstraint!

            switch sender {
            case self.kindTipButton:
                spinner = self.kindTipSpinner
                widthConstraint = self.kindTipButtonWidthConstraint
            case self.excellentTipButton:
                spinner = self.excellentTipSpinner
                widthConstraint = self.excellentTipButtonWidthConstraint
            default:
                spinner = self.incredibleTipSpinner
                widthConstraint = self.incredibleTipButtonWidthConstraint
            }

            if flag {
                spinner.startAnimating()
                widthConstraint.constant = spinner.bounds.width
                spinner.color = sender.backgroundColor
            } else {
                spinner.stopAnimating()
                widthConstraint.constant = self.defaultTipButtonsWidth
            }

            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
                sender.alpha = flag ? 0.0 : 1.0
            }
        }
    }

    func showProfile(_ url: URL) {
        let safari = SFSafariViewController(url: url)
        safari.dismissButtonStyle = .close

        self.present(safari, animated: true)
    }

  func requestProduct(_ id: String, sender: UIButton) {
    self.showSpinner(true, senders: [sender])

    Purchases.shared.getProducts([id]) { [weak self] products in
      guard let product = products.first else {
        self?.showAlert("error_title".localized, message: "network_error_title".localized)
        return
      }

      Purchases.shared.purchase(product: product) { _, _, error, userCancelled in
        guard let self = self else { return }

        self.showSpinner(false, senders: [sender])

        guard !userCancelled else { return }

        if let error = error {
          self.showAlert("error_title".localized, message: error.localizedDescription)
          return
        }

        self.view.startConfetti()

        var completion: (() -> Void)?
        var title = "thanks_amazing_title".localized

        // On first visit, dismiss VC after the alert is dismissed
        if !self.viewModel.hasMadeDonation() {
          completion = {
            self.dismiss(animated: true, completion: nil)
          }
          title = "thanks_title".localized
        }

        self.showAlert(title, message: nil, style: .alert, completion: completion)

        self.viewModel.handleNewDonation()
      }
    }
  }
}

extension PlusViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.contributors.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // swiftlint:disable force_cast
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ContributorViewCell", for: indexPath) as! ContributorCellView
        // swiftlint:enable force_cast

        let contributor = self.contributors[indexPath.item]

        cell.imageView.kf.setImage(with: contributor.avatarURL)

        return cell
    }
}

extension PlusViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let contributor = self.contributors[indexPath.item]

        self.showProfile(contributor.profileURL)
    }
}

extension PlusViewController: Themeable {
    func applyTheme(_ theme: SimpleTheme) {
        self.view.backgroundColor = theme.systemGroupedBackgroundColor

        for label in self.titleLabels {
            label.textColor = theme.primaryColor
        }

        for label in self.detailLabels {
            label.textColor = theme.secondaryColor
        }

        for image in self.imageViews {
            image.tintColor = theme.linkColor
        }
    }
}
