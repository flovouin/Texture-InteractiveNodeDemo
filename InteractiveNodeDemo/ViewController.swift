//
//  ViewController.swift
//  InteractiveNodeDemo
//
//  Created by Flo Vouin on 30/05/2017.
//  Copyright © 2017 flovouin. All rights reserved.
//

import AsyncDisplayKit

class ViewController: ASViewController<MainNode> {
    init() {
        super.init(node: MainNode())
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
