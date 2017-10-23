//
//  DeckTransitioningDelegate.swift
//  DeckTransition
//
//  Created by Harshil Shah on 15/10/16.
//  Copyright © 2016 Harshil Shah. All rights reserved.
//

import UIKit

public final class DeckTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate, DeckPresentationControllerDelegate {
	
	// MARK:- Public variables
	
	/// A variable indicating whether or not the presenting view controller
	/// can currently be dismissed using a pan gestures from top to bottom.
	///
	/// When set to `true`, this allows the presented modal view to be dismissed
	/// using a pan gesture. The default value of this property is `true`
	public var isDismissEnabled = true
	
	// MARK:- Private variables
	
	private let presentDuration: TimeInterval?
	private let presentAnimation: (() -> ())?
	private let presentCompletion: ((Bool) -> ())?
	private let dismissDuration: TimeInterval?
	private let dismissAnimation: (() -> ())?
	private let dismissCompletion: ((Bool) -> ())?
	
	// MARK:- Initializers
	
	/// Returns a transitioning delegate to perform a card transition. All
	/// parameters are optional. Leaving the duration parameters empty gives you
	/// animations with the default durations (0.3s for both)
	///
	/// - Parameters:
	///	  - presentDuration: The duration for the presentation animation
	///   - presentAnimation: An animation block that will be performed
	///		alongside the card presentation animation
	///   - presentCompletion: A block that will be run after the card has been
	///		presented
	///	  - dismissDuration: The duration for the dismissal animation
	///   - dismissAnimation: An animation block that will be performed
	///		alongside the card dismissal animation
	///   - dismissCompletion: A block that will be run after the card has been
	///		dismissed
	@objc public init(presentDuration: NSNumber? = nil,
	                  presentAnimation: (() -> ())? = nil,
	                  presentCompletion: ((Bool) -> ())? = nil,
	                  dismissDuration: NSNumber? = nil,
	                  dismissAnimation: (() -> ())? = nil,
	                  dismissCompletion: ((Bool) -> ())? = nil) {
		self.presentDuration = presentDuration?.doubleValue
		self.presentAnimation = presentAnimation
		self.presentCompletion = presentCompletion
		self.dismissDuration = dismissDuration?.doubleValue
		self.dismissAnimation = dismissAnimation
		self.dismissCompletion = dismissCompletion
	}
	
	// MARK:- UIViewControllerTransitioningDelegate
    
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return DeckPresentingAnimationController(duration: presentDuration)
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return DeckDismissingAnimationController(duration: dismissDuration)
    }
    
    public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        let presentationController = DeckPresentationController(
			presentedViewController: presented,
			presenting: presenting,
			presentAnimation: presentAnimation,
			presentCompletion: presentCompletion,
			dismissAnimation: dismissAnimation,
			dismissCompletion: dismissCompletion)
        presentationController.transitioningDelegate = self
        return presentationController
    }
    
    // MARK: - DeckPresentationControllerDelegate methods
    
    internal func isDismissGestureEnabled() -> Bool {
        return isDismissEnabled
    }
    
}
