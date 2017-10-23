# DeckTransition

[![CI Status](http://img.shields.io/travis/HarshilShah/DeckTransition.svg)](https://travis-ci.org/HarshilShah/DeckTransition)
[![Version](https://img.shields.io/github/release/HarshilShah/DeckTransition.svg)](https://github.com/HarshilShah/DeckTransition/releases/latest)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-compatible-fb0006.svg)](http://cocoapods.org/pods/DeckTransition)
[![Carthage](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg)](https://github.com/Carthage/Carthage)
[![License](https://img.shields.io/cocoapods/l/DeckTransition.svg)](https://github.com/HarshilShah/DeckTransition/blob/master/LICENSE)
[![Contact](https://img.shields.io/badge/contact-%40HarshilShah1910-3a8fc1.svg)](https://twitter.com/HarshilShah1910)

DeckTransition is an attempt to recreate the card-like transition found in the iOS 10 Apple Music and iMessage apps.

Hereʼs a GIF showing it in action.

![Demo](demo.gif)

## Requirements

- Swift 4
- iOS 9 or later

## Installation

### CocoaPods

To install DeckTransition using [CocoaPods](http://cocoapods.org), add the following line to your Podfile:

```
pod 'DeckTransition', '~> 1.0'
```

### Carthage

To install DeckTransition using [Carthage](https://github.com/Carthage/Carthage), add the following line to your Cartfile:

```
github "HarshilShah/DeckTransition" ~> 1.0
```

## Usage

### Basics

Set `modalPresentationCapturesStatusBarAppearance` to `true` in your modal view controller, and override the `preferredStatusBarStyle` variable to return `.lightContent`.

The background color for the presentation can be changed by changing the `backgroundColor` property of the `window`. This is `.black` by default.

### Presentation

The transition can be called from code or using a storyboard.

To use via storyboards, just setup a custom segue (`kind` set to `custom`), and set the `class` to `DeckSegue`.

Hereʼs a snippet showing usage via code. Just replace `ModalViewController()` with your view controller's class and youʼre good to go.

```swift
let modal = ModalViewController()
let transitionDelegate = DeckTransitioningDelegate()
modal.transitioningDelegate = transitionDelegate
modal.modalPresentationStyle = .custom
present(modal, animated: true, completion: nil)
```

### Dismissal

This is the part where it gets a bit tricky. If youʼve got a fixed-sized i.e. non-scrolling modal, feel free to just skip the rest of this section. Swipe-to-dismiss will work perfectly for you

For modals which have a vertically scrolling layout, the dismissal gesture should be fired only when the view is scrolled to the top. To achieve this behaviour, you need to modify the `isDismissEnabled` property of the `DeckTransitioningDelegate`. (You can also set `isDismissEnabled` to false if you want to disable the swipe-to-dismiss UI.)

The one issue with doing this in response to the scrollviewʼs `contentOffset` is momentum scrolling. When the user pans from top the bottom, once the top of the scrollview is reached (`contentOffset.y` is 0), the dismiss gesture should take over and the scrollview should stop scrolling, not showing the usual iOS bounce effect. The dismiss gesture, however, only responds to pans and not swipes, so should you swipe and not pan, the scrollview will scroll to the top and abruptly stop (as the `contentOffset.y` is  0) without the usual iOS bounce effect.

I've found a temporary workaround for this, the code for this can be found below. Itʼs a bit messy right now, but is the only workaround Iʼve found for this issue (so far). It has one caveat, in that it fails utterly miserably when using with a scrollview whose `backgroundColor` isnʼt `.clear`.
Iʼll update this project if/when I find a better solution.

#### Dismissal code for scrolling modals

First up, make your modal view controller conform to `UIScrollViewDelegate` (or `UITableViewDelegate`/`UITextFieldDelegate`, as the case may be), and assign self as the scrollview's `delegate`.

Next, add this method to your modal view controller, swapping in your scrollviewʼs variable for `textView`.

```swift
func scrollViewDidScroll(_ scrollView: UIScrollView) {
    guard scrollView.isEqual(textView) else {
        return
    }

    if let delegate = transitioningDelegate as? DeckTransitioningDelegate {
        if scrollView.contentOffset.y > 0 {
            // Normal behaviour if the `scrollView` isn't scrolled to the top
            scrollView.bounces = true
            delegate.isDismissEnabled = false
        } else {
            if scrollView.isDecelerating {
                // If the `scrollView` is scrolled to the top but is decelerating
                // that means a swipe has been performed. The view and
                // scrollviewʼs subviews are both translated in response to this.
                view.transform = CGAffineTransform(translationX: 0, y: -scrollView.contentOffset.y)
                scrollView.subviews.forEach {
                    $0.transform = CGAffineTransform(translationX: 0, y: scrollView.contentOffset.y)
                }
            } else {
                // If the user has panned to the top, the scrollview doesnʼt bounce and
                // the dismiss gesture is enabled.
                scrollView.bounces = false
                delegate.isDismissEnabled = true
            }
        }
    }
}
```

### Snapshots

For a variety of reasons, and especially because of iOS 11's safe area layout, DeckTransition uses a snapshot of your presenting view controller's view instead of using the view directly. This view is automatically updated whenever the frame is resized.

However, there can be some cases where you might want to update the snapshot view by yourself, and this can be achieved using the following one line snippet:

```swift
(presentationController as? DeckSnapshotUpdater)?.requestPresentedViewSnapshotUpdate()
```

All this does is request the presentation controller to update the snapshot.

You can also choose to update snapshot directly from the presenting view controller, as follows:

```swift
(presentedViewController?.presentationController as? DeckSnapshotUpdater)?.requestPresentedViewSnapshotUpdate()
```

It's worth noting that updating the snapshot is an expensive process and should only be used if necessary, for example if you are updating your entire app's theme.

## Apps Using DeckTransition
- [Petty](https://zachsim.one/projects/petty) by [Zach Simone](https://twitter.com/zachsimone)
- [Bitbook](https://bitbookapp.com) by [Sammy Gutierrez](https://sammygutierrez.com)

Feel free to submit a PR if you’re using this library in your apps

## Author

Written by [Harshil Shah](https://twitter.com/HarshilShah1910)

## License

DeckTransition is available under the MIT license. See the LICENSE file for more info.
