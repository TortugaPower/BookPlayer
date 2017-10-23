## Changelog

## 1.4.0 Release notes (21/10/2017)

- Updated animations to work much better when presenting mutliple view controllers using DeckTransition
- Fixes an issue where the appearance method calls were sometimes unbalanced

## 1.3.4 Release notes (13/10/2017)
----

- Fixed an issue where rotation would break the rounded corners

## 1.3.3 Release notes (11/10/2017)
----

- Corner rounding is now animated

## 1.3.2 Release notes (1/10/2017)
----

- Moved appearance transition methods to the presentation controller

1.3.1 Release notes (26/9/2017)
----

- Fixed the alpha animation during presentation

1.3.0 Release notes (22/9/2017)
----

- Support for safe area based layouts
- Added a new `DeckSnapshotUpdater` API to update presenting view snapshots

1.2.0 Release notes (17/9/2017)
----

Rounded corners are now manually rendered without using a mask

1.1.0 Release notes (15/9/2017)
----

Adds support for iPhone X

1.0.4 Release notes (10/9/2017)
----

Fixed an issue where touches to the presentedView’s subview touches would be cancelled

1.0.3 Release notes (5/9/2017)
----

Fixed an issue caused when the presented view controller presented and then dismissed a view controller

1.0.2 Release notes (25/8/2017)
----

Fixes an issue with Xcode 9’s new build system

1.0.1 Release notes (5/8/2017)
----

Fixes an exception caused by KVO observers never being removed

1.0.0 Release notes (5/8/2017)
----

DeckTransition is finally at 1.0! 🎉 Here’s a summary of all the changes in this version

- Vastly improved performance
- Reorganized project structure
- Support for Carthage
- All “magic numbers” have been refactored out

One small change needs to be implemented in pre-1.0 projects to maintain compatibility with this version of DeckTransition. The entirety of the change consists of replacing the following line of code in your modal view controller’s `UIScrollViewDelegate` implementation

```swift
scrollView.transform = CGAffineTransform(translationX: 0, y: scrollView.contentOffset.y)
```

with the block that follows below:

```swift
scrollView.subviews.forEach {
    $0.transform = CGAffineTransform(translationX: 0, y: scrollView.contentOffset.y)
}
```

The implementation example in the ReadMe has been updated to reflect this.

0.4.0 Release notes (2/8/2017)
----

### API Breaking Changes
- The `DeckTransitioningDelegate` initializer now requires `NSNumber` arguments for animation duration
- A snapshot of the presenting view controller is shown instead of the view itself

### Other Changes
- Fixed Objective-C compatibility issues
- Fixed a host of bugs related to the double height status bar and rotation
- You can now use `pod try` to try the library

0.3.0 Release notes (14/5/2017)
----

- The transition can now be customized by passing in custom animation durations, other animations to be performed alongside the stock animation, and completion handlers

0.2.0 Release notes (5/3/2017)
----

- Made the dismissal gesture friction more realistic

0.1.2 Release notes (27/2/2017)
----

- Fixed an issue where touches to the presented view were being delayed

0.1.1 Release notes (2/12/2016)
----

- Fixed an issue which may prevent masking for the presenting view controller
- Made the example application universal and added icons

0.1.0 Release notes (18/10/2016)
----

- Initial release
