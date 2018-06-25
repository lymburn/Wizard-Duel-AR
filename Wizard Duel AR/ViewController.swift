//
//  ViewController.swift
//  Wizard Duel AR
//
//  Created by Eugene Lu on 2018-06-25.
//  Copyright © 2018 Eugene Lu. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWand()
        sceneView.delegate = self
        sceneView.showsStatistics = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    fileprivate func setupWand() {
        //Add wand node
        let wandScene = SCNScene(named: "art.scnassets/Wand.scn")
        let wandNode = wandScene?.rootNode.childNode(withName: "Wand", recursively: false)
        wandNode?.position = SCNVector3(0, -0.1, -0.6)
        sceneView.pointOfView?.addChildNode(wandNode!)
    }
}
