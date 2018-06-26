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

class ViewController: UIViewController {

    @IBOutlet weak var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWand()
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.autoenablesDefaultLighting = true
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
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        drawSpellLight()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        sceneView.pointOfView?.enumerateChildNodes {(node, _) in
            if node.name == "light" {
                node.removeFromParentNode()
            }
        }
    }
    
    fileprivate func setupWand() {
        //Attach wand node to camera view
        let wandScene = SCNScene(named: "art.scnassets/Wand.scn")
        let wandNode = wandScene?.rootNode.childNode(withName: "Wand", recursively: false)
        wandNode?.geometry?.firstMaterial?.specular.contents = UIColor.white
        wandNode?.position = SCNVector3(0.1, -0.2, -0.8)
        wandNode?.name = "wand"
        sceneView.pointOfView?.addChildNode(wandNode!)
    }
}

extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    }
    
    fileprivate func drawSpellLight() {
        //Draw a circle indicating a spell is being channelled
        let ball = SCNNode()
        ball.position = SCNVector3(0.01, -0.03, -0.8)
        ball.name = "light"
        
        let fire = SCNParticleSystem(named: "Fireball.scnp", inDirectory: nil)!
        fire.particleSize = 0.1
        ball.addParticleSystem(fire)
        sceneView.pointOfView?.addChildNode(ball)
    }
}

extension ViewController {
    fileprivate func getCameraPosition() -> SCNVector3 {
        let pointOfView = sceneView.pointOfView!
        let transform = pointOfView.transform
        let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
        let location = SCNVector3(transform.m41, transform.m42, transform.m43)
        let position = orientation + location
        return position
    }
    
    fileprivate func getCameraOrientation() -> SCNVector3 {
        let pointOfView = sceneView.pointOfView!
        let transform = pointOfView.transform
        let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
        return orientation
    }
}


