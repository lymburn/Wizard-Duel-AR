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
    case player = 2
    case enemyProjectileNode = 3
}

class ViewController: UIViewController {
    var player: SCNNode?
    var spellNode = SCNNode()
    var wandNode = SCNNode()
    var projectileNode = SCNNode()
    var timer: Timer!
    var score: Int = 0
    fileprivate var isCastingSpell: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupWand()
        setupPlayerView()
        
        sceneView.delegate = self
        sceneView.scene.physicsWorld.contactDelegate = self
        sceneView.showsStatistics = true
        sceneView.autoenablesDefaultLighting = true

        //Repeatedly fire enemy projectiles
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) {(timer) in
            self.generateRandomProjectiles()
            //Update score each time user dodges or intercepts a projectile
            self.score += 1
            self.scoreLabel.text = "\(self.score)"
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        //sceneView.debugOptions = [SCNDebugOptions.showPhysicsShapes]
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
    
    let sceneView: ARSCNView = {
        let view = ARSCNView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let scoreLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white
        label.text = "0"
        label.font = UIFont(name: "Helvetica", size: 50)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    fileprivate func setupViews() {
        view.addSubview(sceneView)
        view.addSubview(scoreLabel)
        updateViewConstraints()
    }
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        sceneView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        scoreLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16).isActive = true
        scoreLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8).isActive = true
    }
    
    fileprivate func setupWand() {
        //Attach wand node to camera view
        let wandScene = SCNScene(named: "art.scnassets/Wand.scn")
        wandNode = (wandScene?.rootNode.childNode(withName: "Wand", recursively: false))!
        wandNode.geometry?.firstMaterial?.specular.contents = UIColor.white
        wandNode.position = SCNVector3(0.1, -0.2, -0.8)
        sceneView.pointOfView?.addChildNode(wandNode)
    }
    
    fileprivate func setupPlayerView() {
        //Set up physics body for player's point of view to receive collision events
        sceneView.pointOfView?.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: SCNPlane(width: 0.01, height: 0.01), options: nil))
        sceneView.pointOfView?.physicsBody?.categoryBitMask = BitMaskCategory.player.rawValue
        sceneView.pointOfView?.physicsBody?.contactTestBitMask = BitMaskCategory.enemyProjectileNode.rawValue
        sceneView.pointOfView?.physicsBody?.collisionBitMask = BitMaskCategory.enemyProjectileNode.rawValue
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
        if nodeA.physicsBody?.categoryBitMask != BitMaskCategory.player.rawValue && nodeB.physicsBody?.categoryBitMask != BitMaskCategory.player.rawValue {
            //If neither bodies is the player, then the player spell and enemy projectile must have collided
            handleProjectileCollision(contact: contact)
        } else {
            //If enemy projectile hit player
            handlePlayerHitCollision(contact: contact)
        }
    }
}

fileprivate extension ViewController {
    func drawSpellLight() {
        //Draw a circle indicating a spell is being channelled
        spellNode = SCNNode()
        spellNode.pivot = SCNMatrix4MakeTranslation(0, 0, 140)
        spellNode.physicsBody?.categoryBitMask = BitMaskCategory.spellNode.rawValue
        spellNode.physicsBody?.contactTestBitMask = BitMaskCategory.enemyProjectileNode.rawValue
        
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
    
    func handleProjectileCollision(contact: SCNPhysicsContact) {
        let nodeA = contact.nodeA
        let nodeB = contact.nodeB
        
        createExplosion(at: contact.contactPoint, withSize: 0.5, duration: 0.1, color: nil)
        nodeA.removeFromParentNode()
        nodeB.removeFromParentNode()
    }
    
    func handlePlayerHitCollision(contact: SCNPhysicsContact) {
        //Determine which node is the player
        let nodeA = contact.nodeA
        let nodeB = contact.nodeB
        if nodeA.physicsBody?.categoryBitMask == BitMaskCategory.player.rawValue {
            //If node A is the player
            player = nodeA
            //Remove spell node when hit
            nodeB.removeFromParentNode()
        } else {
            //If node B is the player
            player = nodeB
            //Remove spell node when hit
            nodeA.removeFromParentNode()
        }
        createExplosion(at: contact.contactPoint, withSize: 0.1, duration: 2, color: UIColor(rgb: 0x50FF2F))
        timer.invalidate()
    }
    
    func createExplosion(at contactPoint: SCNVector3, withSize size: CGFloat, duration: CGFloat, color: UIColor?) {
        //Create explosion at contact point of player
        let explosion = SCNParticleSystem(named: "Explosion.scnp", inDirectory: nil)!
        explosion.loops = false
        explosion.particleLifeSpan = duration
        explosion.particleSize = size
        let explosionNode = SCNNode()
        explosionNode.addParticleSystem(explosion)
        explosionNode.position = contactPoint
        if let particleColor = color {
            explosion.particleColor = particleColor
            explosion.acceleration = SCNVector3(0, 4, 0)
        }
        sceneView.scene.rootNode.addChildNode(explosionNode)
    }
    
    func generateRandomProjectiles() {
        //Create random projectiles that fire towards the camera position
        let orientation = getCameraOrientation()
        let randomOffsetZ = -Int(arc4random_uniform(2) + UInt32(4))
        let randomOffsetVector = SCNVector3(0, 0, randomOffsetZ)
        projectileNode.position = randomOffsetVector
        let fire = SCNParticleSystem(named: "Avada Kedavra.scnp", inDirectory: nil)!
        fire.particleSize = 0.1
        projectileNode.addParticleSystem(fire)
        
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: projectileNode, options: nil))
        body.applyForce(SCNVector3(-orientation.x*4, -orientation.y*4, -orientation.z*4), asImpulse: true)
        body.isAffectedByGravity = false
        projectileNode.physicsBody = body
        projectileNode.physicsBody?.categoryBitMask = BitMaskCategory.enemyProjectileNode.rawValue
        projectileNode.physicsBody?.contactTestBitMask = BitMaskCategory.player.rawValue | BitMaskCategory.spellNode.rawValue
        
        sceneView.pointOfView?.addChildNode(projectileNode)
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


