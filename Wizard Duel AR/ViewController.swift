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
    case spellNode = 1
    case target = 2
}

class ViewController: UIViewController {

    @IBOutlet weak var sceneView: ARSCNView!
    var target: SCNNode?
    var spellNode = SCNNode()
    var wandNode = SCNNode()
    var projectileNode = SCNNode()
    fileprivate var isCastingSpell: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWand()
        generateRandomProjectiles()
        sceneView.delegate = self
        sceneView.scene.physicsWorld.contactDelegate = self
        sceneView.showsStatistics = true
        sceneView.autoenablesDefaultLighting = true

        sceneView.pointOfView?.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: SCNPlane(width: 0.01, height: 0.01), options: nil))
        sceneView.pointOfView?.physicsBody?.categoryBitMask = BitMaskCategory.target.rawValue
        sceneView.pointOfView?.physicsBody?.contactTestBitMask = BitMaskCategory.spellNode.rawValue
    
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        sceneView.debugOptions = [SCNDebugOptions.showPhysicsShapes]
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //Draw channelling spell light
        castSpell()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        //Remove the spell light when user stops holding
        useSpell()
    }
    
    fileprivate func setupWand() {
        //Attach wand node to camera view
        let wandScene = SCNScene(named: "art.scnassets/Wand.scn")
        wandNode = (wandScene?.rootNode.childNode(withName: "Wand", recursively: false))!
        wandNode.geometry?.firstMaterial?.specular.contents = UIColor.white
        wandNode.position = SCNVector3(0.1, -0.2, -0.8)
        sceneView.pointOfView?.addChildNode(wandNode)
    }
}

extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    }
}

extension ViewController: SCNPhysicsContactDelegate {
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        handleCollision(contact: contact)
    }
}

fileprivate extension ViewController {
    func drawSpellLight() {
        //Draw a circle indicating a spell is being channelled
        spellNode = SCNNode()
        spellNode.pivot = SCNMatrix4MakeTranslation(0, 0, 140)
        spellNode.physicsBody?.categoryBitMask = BitMaskCategory.spellNode.rawValue
        spellNode.physicsBody?.contactTestBitMask = BitMaskCategory.target.rawValue
        
        let fire = SCNParticleSystem(named: "Fireball.scnp", inDirectory: nil)!
        fire.particleSize = 0.1
        spellNode.addParticleSystem(fire)
        wandNode.addChildNode(spellNode)
    }
    
    //Fire a spell
    func fireSpell() {
        let orientation = getCameraOrientation()
        
        //Create physics body and apply force to spell
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: spellNode, options: nil))
        body.isAffectedByGravity = false
        spellNode.pivot = SCNMatrix4MakeTranslation(0, 0, 70)
        let force = SCNVector3(orientation.x*5, orientation.y*5, orientation.z*5)
        body.applyForce(force, asImpulse: true)
        body.friction = 0.0
        spellNode.physicsBody = body
        
        //Delete spell after 1.5 seconds
        spellNode.runAction(SCNAction.sequence([SCNAction.wait(duration: 1.5),
                                           SCNAction.removeFromParentNode()]))
    }
    
    func castSpell() {
        //Move wand down and draw spell light to indicate casting
        if !isCastingSpell && wandNode.actionKeys.isEmpty {
            let action = SCNAction.rotateBy(x: CGFloat(-15).degreesToRadians, y: 0, z: 0, duration: 0.2)
            wandNode.runAction(action) {
                self.drawSpellLight()
                self.isCastingSpell = true
            }
        }
    }
    
    func useSpell() {
        //Fire spell and move wand back to original position
        if isCastingSpell {
            fireSpell()
            let action = SCNAction.rotateTo(x: CGFloat(35).degreesToRadians, y: CGFloat(15).degreesToRadians, z: 0, duration: 0.2)
            wandNode.runAction(action)
            isCastingSpell = false
        }
    }
    
    func handleCollision(contact: SCNPhysicsContact) {
        //Determine which node is the target
        let nodeA = contact.nodeA
        let nodeB = contact.nodeB
        if nodeA.physicsBody?.categoryBitMask == BitMaskCategory.target.rawValue {
            //If node A is the target
            target = nodeA
            //Remove spell node when hit
            nodeB.removeFromParentNode()
        } else {
            //If node B is the target
            target = nodeB
            //Remove spell node when hit
            nodeA.removeFromParentNode()
        }
        
        //Create explosion at contact point of target
        let explosion = SCNParticleSystem(named: "Explosion.scnp", inDirectory: nil)!
        explosion.loops = false
        explosion.particleLifeSpan = 2
        explosion.particleSize = 0.1
        let explosionNode = SCNNode()
        explosionNode.addParticleSystem(explosion)
        explosionNode.position = contact.contactPoint
        sceneView.scene.rootNode.addChildNode(explosionNode)
    }
    
    func generateRandomProjectiles() {
        //Create random projectiles that fire towards the camera position
        let cameraPosition = getCameraPosition()
        let orientation = getCameraOrientation()
        projectileNode.position = SCNVector3(cameraPosition.x*3, cameraPosition.y*3, cameraPosition.z*3)
        let fire = SCNParticleSystem(named: "Fireball.scnp", inDirectory: nil)!
        fire.particleSize = 0.1
        projectileNode.addParticleSystem(fire)
        
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: projectileNode, options: nil))
        body.applyForce(SCNVector3(-orientation.x, -orientation.y, -orientation.z), asImpulse: true)
        body.isAffectedByGravity = false
        projectileNode.physicsBody = body
        
        sceneView.scene.rootNode.addChildNode(projectileNode)
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


