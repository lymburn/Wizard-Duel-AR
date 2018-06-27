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

enum BitMaskCategory: Int {
    case spell = 1
    case target = 2
}

class ViewController: UIViewController {

    @IBOutlet weak var sceneView: ARSCNView!
    var target: SCNNode?
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWand()
        sceneView.delegate = self
        sceneView.scene.physicsWorld.contactDelegate = self
        sceneView.showsStatistics = true
        sceneView.autoenablesDefaultLighting = true
        
        let box = SCNNode(geometry: SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0))
        box.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        box.position = SCNVector3(0,0,0)
        box.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: box, options: nil))
        box.physicsBody?.categoryBitMask = BitMaskCategory.target.rawValue
        box.physicsBody?.contactTestBitMask = BitMaskCategory.spell.rawValue
        sceneView.scene.rootNode.addChildNode(box)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //Draw channelling spell light
        drawSpellLight()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        //Remove the spell light when user stops holding
        fireSpell()
    }
    
    var spell = SCNNode()
    var wandNode = SCNNode()
    
    fileprivate func setupWand() {
        //Attach wand node to camera view
        let wandScene = SCNScene(named: "art.scnassets/Wand.scn")
        wandNode = (wandScene?.rootNode.childNode(withName: "Wand", recursively: false))!
        wandNode.geometry?.firstMaterial?.specular.contents = UIColor.white
        wandNode.position = SCNVector3(0.1, -0.2, -0.8)
        wandNode.name = "wand"
        sceneView.pointOfView?.addChildNode(wandNode)
    }
}

extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    }
}

extension ViewController: SCNPhysicsContactDelegate {
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let nodeA = contact.nodeA
        let nodeB = contact.nodeB
        if nodeA.physicsBody?.categoryBitMask == BitMaskCategory.target.rawValue {
            //If node A is the target
            target = nodeA
            //Remove spell node when hit
            nodeB.removeFromParentNode()
        } else {
            target = nodeB
            //Remove spell node when hit
            nodeA.removeFromParentNode()
        }
        let explosion = SCNParticleSystem(named: "Explosion.scnp", inDirectory: nil)!
        explosion.loops = false
        explosion.particleLifeSpan = 4
        explosion.particleSize = 0.3
        let explosionNode = SCNNode()
        explosionNode.addParticleSystem(explosion)
        explosionNode.position = contact.contactPoint
        sceneView.scene.rootNode.addChildNode(explosionNode)
        target?.removeFromParentNode()
    }
}

fileprivate extension ViewController {
    func drawSpellLight() {
        //Draw a circle indicating a spell is being channelled
        spell = SCNNode()
        spell.position = SCNVector3(0.01, -0.03, -0.8)
        spell.name = "spell light"
        spell.physicsBody?.categoryBitMask = BitMaskCategory.spell.rawValue
        spell.physicsBody?.contactTestBitMask = BitMaskCategory.target.rawValue
        
        let fire = SCNParticleSystem(named: "Fireball.scnp", inDirectory: nil)!
        fire.particleSize = 0.1
        spell.addParticleSystem(fire)
        sceneView.pointOfView?.addChildNode(spell)
    }
    
    //Fire a spell
    func fireSpell() {
        let orientation = getCameraOrientation()
        
        //Apple force to spell
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: spell, options: nil))
        body.isAffectedByGravity = false
        let force = SCNVector3(orientation.x*5, orientation.y*5, orientation.z*5)
        body.applyForce(force, asImpulse: true)
        body.friction = 0.0
        spell.physicsBody = body
        
        //Delete spell after 2 seconds
        spell.runAction(SCNAction.sequence([SCNAction.wait(duration: 2),
                                           SCNAction.removeFromParentNode()]))
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


