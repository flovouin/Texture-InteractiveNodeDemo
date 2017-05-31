//
//  MainNode.swift
//  InteractiveNodeDemo
//
//  Created by Flo Vouin on 30/05/2017.
//  Copyright © 2017 flovouin. All rights reserved.
//

import AsyncDisplayKit

/**
    The list of states in which the node can be. Forcing the enum to be Int simply to make it easy
    to use as a template.
*/
enum MainNodeState: Int {
    case first
    case second
}

class MainNode: InteractiveStateNode<MainNodeState> {
    private let movingNode = ASDisplayNode()
    private let vanishingNode = ASButtonNode()

    let translationLength: CGFloat = 300.0

    // MARK: - Lifecycle
    init() {
        // The gesture recognizers specified here will be added to the node's view. The delegate is
        // left untouched, so that you can declare yourself as the delegate and have more precise
        // control over when the recognizer is active or should be canceled.
        // The following two parameters correspond to the UIViewPropertyAnimator initializer.
        super.init(gestureRecognizers: [UIPanGestureRecognizer()], animationDuration: 0.2,
                   timingParameters: UICubicTimingParameters(animationCurve: .linear),
                   initialState: .first)

        self.minFractionToComplete = 0.3

        self.backgroundColor = .black
        self.movingNode.backgroundColor = .red
        self.vanishingNode.backgroundColor = .green
        self.vanishingNode.addTarget(self, action: #selector(self.pressVanishingNode(sender:)),
                                     forControlEvents: .touchUpInside)
    }

    // MARK: - User actions
    func pressVanishingNode(sender: ASButtonNode) {
        // Triggers a non-interactive change of state.
        self.setState(.first, animated: true)
    }

    // MARK: - Layout
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange,
                                     for state: MainNodeState) -> ASLayoutSpec {
        // This is just like the good ol' layoutSpecThatFits, except the extra state parameter can
        // be used to set up the layout for a given state.
        self.movingNode.style.preferredSize = CGSize(width: 50.0, height: 50.0)
        self.vanishingNode.style.preferredSize = CGSize(width: 80.0, height: 80.0)

        var movingNodeInsets = UIEdgeInsets(top: 20.0, left: 20.0, bottom: 0.0, right: 0.0)
        if state == .second {
            movingNodeInsets.top += self.translationLength
        }
        let movingNodeLayout = ASRelativeLayoutSpec(
            horizontalPosition: .start, verticalPosition: .start, sizingOption: .minimumSize,
            child: ASInsetLayoutSpec(insets: movingNodeInsets, child: self.movingNode))

        let vanishingNodeInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 20.0, right: 20.0)
        let vanishingNodeLayout = ASRelativeLayoutSpec(
            horizontalPosition: .end, verticalPosition: .end, sizingOption: .minimumSize,
            child: ASInsetLayoutSpec(insets: vanishingNodeInset, child: self.vanishingNode))

        return ASOverlayLayoutSpec(child: movingNodeLayout, overlay: vanishingNodeLayout)
    }

    override func setNodeProperties(for state: MainNodeState) {
        // Animatable properties can be set here and will be animated during the transition.
        self.vanishingNode.alpha = state == .second ? 1.0 : 0.0
    }

    override func nodes(for state: MainNodeState?) -> [ASDisplayNode] {
        // I'm not really proud of this method. It should return the nodes that should be in the
        // hierarchy for the given state, or all nodes if state is nil.
        // The reason I don't use the layout spec for that is that it would be impossible to
        // animate the frame of a (dis)appearing node. This is also one of the main drawbacks of the
        // current Texture mechanism for layout transitions.
        guard let state = state else { return [self.movingNode, self.vanishingNode] }

        switch state {
        case .first:
            // In the first state, the vanishingNode is not in the hierarchy.
            return [self.movingNode]
        default:
            return [self.movingNode, self.vanishingNode]
        }
    }

    override func didBeginGestureToState(recognizer: UIGestureRecognizer) -> MainNodeState? {
        // Called when one of the gesture recognizers is in the begin state. This method should
        // return to which state the beginning transition should go (or nil if no transition should
        // occur).
        // This can be coupled with the implementation of the recognizer's delegate if more control
        // is needed over when (not) to start a transition, e.g. to give way to another gesture
        // recognizer, etc.
        switch self.state {
        case .first:
            return .second
        case .second:
            return .first
        }
    }

    override func didChangeGestureToFractionComplete(recognizer: UIGestureRecognizer) -> CGFloat {
        // Called when the gesture recognizer changes. The goal of this method is to update the
        // progress of the animation. It could also rely on external factors / UI components.
        guard let recognizer = recognizer as? UIPanGestureRecognizer else { return 0.0 }

        let gestureOrientationCoeff: CGFloat = self.destinationState == .second ? 1.0 : -1.0
        let translation = recognizer.translation(in: self.view)
        let reducedTranslation = (gestureOrientationCoeff * translation.y) / self.translationLength
        return max(0.0, min(1.0, reducedTranslation))
    }

    override func didStartAnimation(interactive: Bool) {
        // This is called at the beginning of an animation. This can for example be used to pause a
        // video, resign the first responder, etc.
    }

    override func didFinishAnimation(interactive: Bool, didComplete: Bool) {
        // The counterpart of didStartAnimation.
    }
}
