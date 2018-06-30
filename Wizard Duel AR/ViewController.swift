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
    let screenSize = UIScreen.main.bounds
    var isCastingSpell: Bool = false
    var playerIsAlive: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupWand()
        setupPlayerView()

        sceneView.scene.physicsWorld.contactDelegate = self
        sceneView.autoenablesDefaultLighting = true
        
        //If user has already seen tutorial, start firing projectiles
        if !UserDefaults.isFirstLaunch() {
            instructionLabel.alpha = 0
            scoreLabel.alpha = 1
            startGame()
        } else {
            scoreLabel.alpha = 0
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: .UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: .UIApplicationDidBecomeActive, object: nil)
    }
    
    @objc func willResignActive() {
        timer.invalidate()
        timer = nil
    }
    
    @objc func didBecomeActive() {
        if timer == nil {
            startGame()
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
        print("back")
        sceneView.session.pause()
        timer.invalidate()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print(instructionLabel.alpha)
        if instructionLabel.alpha == 1.0 {
            //Draw channelling spell light
            //If instruction label is shown, game is first launch
            startGame()
            scoreLabel.alpha = 1
            instructionLabel.alpha = 0
            castSpell()
        } else if playerIsAlive {
            //If player is on dead screen, restart game when tapped
            castSpell()
        } else if !playerIsAlive {
            restartGame()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if playerIsAlive {
            //Remove the spell light when user stops holding
            useSpell()
        }
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
        label.font = UIFont.systemFont(ofSize: 50, weight: UIFont.Weight.thin)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let bestScoreLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white
        label.text = "BEST"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 50, weight: UIFont.Weight.thin)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alpha = 0
        return label
    }()
    
    let tapToRestartLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white
        label.text = "TAP TO RESTART"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 30, weight: UIFont.Weight.thin)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alpha = 0
        return label
    }()
    
    let instructionLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white
        label.text = "Dodge the enemy spells or intercept them. Press and release to fire your own spells."
        label.numberOfLines = 5
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 30, weight: UIFont.Weight.medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let skullImage: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "Skull"))
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.alpha = 0
        return iv
    }()
    
    fileprivate func setupViews() {
        view.addSubview(sceneView)
        view.addSubview(scoreLabel)
        view.addSubview(skullImage)
        view.addSubview(bestScoreLabel)
        view.addSubview(tapToRestartLabel)
        view.addSubview(instructionLabel)
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
        
        bestScoreLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8).isActive = true
        bestScoreLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8).isActive = true
        bestScoreLabel.bottomAnchor.constraint(equalTo: skullImage.topAnchor).isActive = true
        bestScoreLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16).isActive = true
        
        let skullSize: CGFloat
        if UIDevice.current.orientation == UIDeviceOrientation.landscapeLeft
            || UIDevice.current.orientation == UIDeviceOrientation.landscapeRight {
            //If landscape
            skullSize = screenSize.height*0.5
        } else {
            //If portrait
            skullSize = screenSize.width*0.5
        }
        
        skullImage.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        skullImage.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        skullImage.widthAnchor.constraint(equalToConstant: skullSize).isActive = true
        skullImage.heightAnchor.constraint(equalToConstant: skullSize).isActive = true
        
        tapToRestartLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8).isActive = true
        tapToRestartLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8).isActive = true
        tapToRestartLabel.topAnchor.constraint(equalTo: skullImage.bottomAnchor, constant: 16).isActive = true
        tapToRestartLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8).isActive = true
        
        instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16).isActive = true
        instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16).isActive = true
        instructionLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: screenSize.height*0.2).isActive = true
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
        //Invalidate timer
        timer.invalidate()
        
        //Determine which node is the player
        let nodeA = contact.nodeA
        let nodeB = contact.nodeB
        if nodeA.physicsBody?.categoryBitMask == BitMaskCategory.player.rawValue {
            //If node A is the player
            player = nodeA
        } else {
            //If node B is the player
            player = nodeB
        }
        createExplosion(at: contact.contactPoint, withSize: 0.1, duration: 2, color: UIColor(rgb: 0x50FF2F))

        DispatchQueue.main.async {
            //Show skull indicating player death
            UIView.animate(withDuration: 2) {
                self.skullImage.alpha = 1
                self.bestScoreLabel.alpha = 1
                self.bestScoreLabel.text = "BEST \(self.score)"
                self.tapToRestartLabel.alpha = 1
                self.playerIsAlive = false
            }
        }
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
        projectileNode.particleSystems?.first?.particleDiesOnCollision = true
        
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: projectileNode, options: nil))
        body.applyForce(SCNVector3(-orientation.x*4, -orientation.y*4, -orientation.z*4), asImpulse: true)
        body.isAffectedByGravity = false
        projectileNode.physicsBody = body
        projectileNode.physicsBody?.categoryBitMask = BitMaskCategory.enemyProjectileNode.rawValue
        projectileNode.physicsBody?.contactTestBitMask = BitMaskCategory.player.rawValue | BitMaskCategory.spellNode.rawValue
        projectileNode.physicsBody?.collisionBitMask = BitMaskCategory.spellNode.rawValue
        
        sceneView.pointOfView?.addChildNode(projectileNode)
    }
    
    func startGame() {
        //Repeatedly fire enemy projectiles
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) {(timer) in
            self.generateRandomProjectiles()
            //Update score each time user dodges or intercepts a projectile
            self.score += 1
            self.scoreLabel.text = "\(self.score)"
        }
    }
    
    func restartGame() {
        playerIsAlive = true
        score = 0
        scoreLabel.text = "0"
        //Hide death screen labels
        bestScoreLabel.alpha = 0
        tapToRestartLabel.alpha = 0
        skullImage.alpha = 0
        
        //Restart firing projectiles
        startGame()
    }
}

extension ViewController {
    fileprivate func getCameraOrientation() -> SCNVector3 {
        let pointOfView = sceneView.pointOfView!
        let transform = pointOfView.transform
        let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
        return orientation
    }
}


