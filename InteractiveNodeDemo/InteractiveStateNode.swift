//
//  InteractiveStateNode.swift
//  InteractiveNodeDemo
//
//  Created by Flo Vouin on 12/04/2017.
//  Copyright © 2017 Narraly. All rights reserved.
//

import AsyncDisplayKit

/**
    A node that handles interactive animations between several states.
*/
class InteractiveStateNode<S: RawRepresentable>: ASDisplayNode where S.RawValue == Int {
    private let animator: UIViewPropertyAnimator

    /**
        The gesture recognizer(s) used to interactively animate state transitions.
    */
    let gestureRecognizers: [UIGestureRecognizer]

    /**
        The minimum value of the fraction when the recognizer ends for the state transition to
        complete. Otherwise the node is reverted to the source state.
    */
    var minFractionToComplete = CGFloat(0.5)

    // MARK: - Lifecycle
    init(gestureRecognizers: [UIGestureRecognizer], animationDuration: TimeInterval,
         timingParameters: UITimingCurveProvider, initialState: S) {
        self.gestureRecognizers = gestureRecognizers
        self.state = initialState
        self.animator = UIViewPropertyAnimator(duration: animationDuration,
                                               timingParameters: timingParameters)

        super.init()
    }

    override func didLoad() {
        super.didLoad()

        for recognizer in self.gestureRecognizers {
            recognizer.addTarget(self, action: #selector(self.gestureDetected(sender:)))
            self.view.addGestureRecognizer(recognizer)
        }
    }

    // MARK: - State
    /**
        The current state for the node.
    */
    private(set) var state: S

    /**
        During interactive animations, the target state in which the node will end up if the
        animation completes.
    */
    private(set) var destinationState: S?

    /**
        Sets the state for the node.

        - Parameters:
            - state: The destination state.
            - animated: Wheter the transition should be animated.
    */
    func setState(_ state: S, animated: Bool = true) {
        if animated {
            self.startAnimation(to: state)
        } else {
            self.state = state
            self.setNeedsLayout()
        }
    }

    // MARK: - Layout
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        return ASLayoutSpec()
    }

    private var isInteractiveTransition = false

    override func animateLayoutTransition(_ context: ASContextTransitioning) {
        let destinationState = self.destinationState ?? self.state
        let interactive = self.isInteractiveTransition

        self.addNodes(for: destinationState, removeOthers: false)
        self.animator.isReversed = false
        self.animator.addCompletion { position in
            let didComplete = position == .end
            if didComplete {
                self.state = destinationState
            }
            self.addNodes(for: self.state, removeOthers: true)
            self.destinationState = nil
            self.isInteractiveTransition = false
            context.completeTransition(didComplete)
            self.didFinishAnimation(interactive: interactive, didComplete: didComplete)
        }
        self.animator.addAnimations {
            self.layout(for: destinationState)
        }

        if interactive {
            self.animator.pauseAnimation()
        } else {
            self.animator.startAnimation()
        }

        self.didStartAnimation(interactive: interactive)
    }

    private func layout(for state: S, layoutAllNodes: Bool = false) {
        let size = ASSizeRangeMake(self.bounds.size)
        let layoutSpec = self.layoutSpecThatFits(size, for: state)
        let nodesLayout = layoutSpec.layoutThatFits(size).filteredNodeLayoutTree()

        for node in (layoutAllNodes ? self.nodes() : self.subnodes) {
            let frame = nodesLayout.frame(for: node)
            if !frame.isNull {
                node.frame = frame
            }
        }

        self.setNodeProperties(for: state)
    }

    override func layout() {
        // Do not layout while an animation is in progress.
        guard self.destinationState == nil else { return }

        self.addNodes(for: self.state, removeOthers: true)
        self.layout(for: self.state, layoutAllNodes: true)
    }

    // MARK: - Overridable methods
    /**
        Should be overriden to provide the layout for a given node state.

        - Parameters:
            - constrainedSize: The constrained size.
            - for: The state.

        - Returns: An ASDK layout.
    */
    func layoutSpecThatFits(_ constrainedSize: ASSizeRange, for state: S) -> ASLayoutSpec {
        return super.layoutSpecThatFits(constrainedSize)
    }

    /**
        Called when the node is first initialised and during transitions. Can be used to set node
        properties (other than their `frame`), like their `alpha`.

        - Parameters:
            - for: The state.
    */
    func setNodeProperties(for state: S) {
    }

    /**
        Adds and removes nodes from the hierarchy. Usually this should not be overriden, but can if
        `node(for:)` does not provide enough flexibility.

        - Parameters:
            - for: The state.
            - removeOthers: If `true`, removes current subnodes that are not present in
                `node(for: state)`.
    */
    func addNodes(for state: S, removeOthers: Bool) {
        let stateNodes = self.nodes(for: state)

        for i in 0..<stateNodes.count where stateNodes[i].supernode == nil {
            if i > 0 {
                self.insertSubnode(stateNodes[i], aboveSubnode: stateNodes[i - 1])
            } else {
                self.addSubnode(stateNodes[i])
            }
        }

        if removeOthers {
            for node in self.subnodes where !stateNodes.contains(node) {
                node.removeFromSupernode()
            }
            for z in 0..<stateNodes.count {
                stateNodes[z].zPosition = CGFloat(z)
            }
        }
    }

    /**
        Should be overriden to provide the subnodes that should be displayed in a given state.

        - Parameters:
            - for: The state, or `nil` if all nodes should be returned.

        - Returns: The list of nodes that should be added to the hierarchy for the given state.
            The nodes are added in order, to handle z-axis stacking.
    */
    func nodes(for state: S? = nil) -> [ASDisplayNode] {
        return self.subnodes
    }

    /**
        Called when one of the gesture recognizers begins tracking a gesture. This method should be
        overriden and return the destination state for the gesture being tracked, or `nil` is the
        recognizer should be cancelled.

        - Parameters:
            - recognizer: The gesture recognizer.

        - Returns: The destination state, or `nil` if the recognizer should be cancelled.
    */
    func didBeginGestureToState(recognizer: UIGestureRecognizer) -> S? {
        return nil
    }

    /**
        Called when a gesture recognizer is tracking a gesture and updated its state. This method
        should be overriden and return the `fractionComplete` for the animation, between `0.0` and
        `1.0`.

        - Parameters:
            - recognizer: The gesture recognizer.

        - Returns: The progress of the current animation, between `0.0` and `1.0`.
    */
    func didChangeGestureToFractionComplete(recognizer: UIGestureRecognizer) -> CGFloat {
        return 0.0
    }

    /**
        Called when an animation begins.

        - Parameters:
            - interactive: Whether the animation is driven by a gesture.
    */
    func didStartAnimation(interactive: Bool) {
    }

    /**
        Called when an animation finishes.

        - Parameters:
            - interactive: Whether the animation was driven by a gesture.
            - didComplete: Whether the animation completed to reach the destination state, or
                returned to the previous state.
    */
    func didFinishAnimation(interactive: Bool, didComplete: Bool) {
    }

    // MARK: - Gesture recognizers
    func gestureDetected(sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .began:
            guard self.animator.state == .inactive,
                let destinationState = self.didBeginGestureToState(recognizer: sender) else {
                sender.isEnabled = false
                return
            }
            self.startInteractiveAnimation(to: destinationState)
        case .ended:
            self.completeOrRevertAnimation()
        case .changed:
            self.animator.fractionComplete =
                self.didChangeGestureToFractionComplete(recognizer: sender)
        case .cancelled:
            sender.isEnabled = true
            self.revertAnimation()
        default:
            break
        }
    }

    // MARK: - Animator
    func startAnimation(to state: S) {
        self.setUpAnimation(to: state, interactive: false)
    }

    private func startInteractiveAnimation(to state: S) {
        guard self.state != state else { return }

        self.setUpAnimation(to: state, interactive: true)
    }

    private func setUpAnimation(to destinationState: S, interactive: Bool,
                                completion: ((Bool) -> Void)? = nil) {
        self.destinationState = destinationState
        self.isInteractiveTransition = interactive

        self.transitionLayout(withAnimation: true, shouldMeasureAsync: false,
                              measurementCompletion: nil)
    }

    private func completeOrRevertAnimation() {
        if self.animator.fractionComplete > self.minFractionToComplete {
            self.completeAnimation()
        } else {
            self.revertAnimation()
        }
    }

    private func completeAnimation() {
        guard self.animator.state == .active else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + kAnimatorDelay) {
            self.animator.startAnimation()
        }
    }

    private func revertAnimation() {
        guard self.animator.state == .active else { return }

        self.animator.isReversed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + kAnimatorDelay) {
            self.animator.startAnimation()
        }
    }
}

private let kAnimatorDelay = DispatchTimeInterval.milliseconds(2)
