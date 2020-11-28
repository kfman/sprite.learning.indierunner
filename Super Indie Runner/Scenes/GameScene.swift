//
//  GameScene.swift
//  Super Indie Runner
//
//  Created by Klaus Fischer on 28.11.20.
//

import SpriteKit

enum GameState{
    case ready, ongoing, paused, finished
}

class GameScene: SKScene {
    
    var worldLayer: Layer!
    var backgroundLayer: RepeatingLayer!
    var mapNode: SKNode!
    var tileMap: SKTileMapNode!
    var player: Player!
    
    var touch = false
    var brake = false
    
    var lastTime: TimeInterval = 0
    var dt: TimeInterval = 0
    
    var gameState = GameState.ready{
        willSet{
            switch newValue {
            case .ongoing:
                player.state = .running
            case .finished:
                player.state = .idle
            default:
                break
            }
        }
    }
    
    override func didMove(to view: SKView) {
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx:0, dy: -6.0)
        createLayers()
    }
    
    func createLayers(){
        worldLayer = Layer()
        addChild(worldLayer)
        
        worldLayer.layerVelocity = CGPoint(x: -200.0, y: 0.0)
        
        backgroundLayer = RepeatingLayer()
        addChild(backgroundLayer)
        
        for i in 0...1 {
            let backgroundImage = SKSpriteNode(imageNamed: GameConstants.StringConstants.worldBackgroundNames[0])
            backgroundImage.name = String(i)
            backgroundImage.scale(to: frame.size, width: false, multiplier: 1.0)
            backgroundImage.anchorPoint = CGPoint.zero
            backgroundImage.position = CGPoint(x: CGFloat(i) * backgroundImage.size.width, y: 0.0)
            backgroundLayer.addChild(backgroundImage)
        }
        backgroundLayer.layerVelocity = CGPoint(x: -100.0, y: 0.0)
        backgroundLayer.zPosition = GameConstants.ZPositions.farBGZ;
        
        worldLayer.zPosition = GameConstants.ZPositions.worldZ
        load(level: "Level_0-1")
        
    }
    
    func load(level: String){
        if let levelNode = SKNode.unarchiveFromFile(file: level){
            mapNode = levelNode
            worldLayer.addChild(mapNode)
            loadTileMap()
        }
    }
    
    func loadTileMap(){
        if let groundTile = mapNode.childNode(withName: GameConstants.StringConstants.groundTilesName) as? SKTileMapNode {
            tileMap = groundTile
            tileMap.scale(to: frame.size, width: false, multiplier: 1.0)
            PhysicsHelper.addPhysicsBody(to: tileMap, and: "ground")
            
            for child in groundTile.children{
                if let sprite = child as? SKSpriteNode, sprite.name != nil{
                    ObjectHelper.handleChild(sprite: sprite, with: sprite.name!)
                }
            }
        }
        
        addPlayer()
    }
    
    func addPlayer(){
        player = Player(imageNamed: GameConstants.StringConstants.playerImageName)
        player.scale(to: frame.size, width: false, multiplier: 0.1)
        
        player.name = GameConstants.StringConstants.playerName
        PhysicsHelper.addPhysicsBody(to: player, with: player.name!)
        player.position = CGPoint(x: frame.midX/2, y: frame.midY)
        player.zPosition = GameConstants.ZPositions.playerZ
        player.loadTextures()
        player.state = .idle
        addChild(player)
        addPlayerActions()
    }
    
    func addPlayerActions(){
        let up = SKAction.moveBy(x: 0.0, y: frame.size.height / 4, duration: 0.4)
        up.timingMode = .easeOut
        
        player.createUserData(entry: up, forKey: GameConstants.StringConstants.jumpUpActionKey)
        
        let move = SKAction.moveBy(x: 0.0, y: player.size.height, duration: 0.4)
        let jump = SKAction.animate(with: player.jumpFrames, timePerFrame: 0.4/Double(player.jumpFrames.count))
        
        let group = SKAction.group([move, jump])
        
        player.createUserData(entry: group, forKey: GameConstants.StringConstants.brakeDescentActionKey)
    }
    
    func jump(){
        player.airborne = true
        player.turnGravity(on: false)
        player.run(player.userData?.value(forKey: GameConstants.StringConstants.jumpUpActionKey ) as! SKAction){
            if self.touch{
                self.player.run(self.player.userData?.value(forKey: GameConstants.StringConstants.jumpUpActionKey) as! SKAction, completion:{
                    self.player.turnGravity(on: true)
                })
            } else {
                self.player.turnGravity(on: true)
            }
        }
    }
    
    func brakeDescent(){
        brake = true
        player.physicsBody!.velocity.dy = 0.0
        
        player.run(player.userData?.value(forKey: GameConstants.StringConstants.brakeDescentActionKey) as! SKAction)
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch gameState {
        case .ready:
            gameState = .ongoing
        case .ongoing:
            touch = true
            if !player.airborne{
                jump()
            }else if !brake {
                brakeDescent()
            }
        default:
            break
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touch = false
        //player.turnGravity(on: true)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touch = false
        //player.turnGravity(on: true)
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
        if lastTime > 0 {
            dt = currentTime - lastTime
        }
        else{
            dt = 0
        }
        lastTime = currentTime
        
        if gameState == .ongoing{
            worldLayer.update(dt)
            backgroundLayer.update(dt)
        }
    }
    
    override func didSimulatePhysics() {
        for node in tileMap[GameConstants.StringConstants.groundNodeName]{
            if let groundNode = node as? GroundNode{
                let groundY = (groundNode.position.y + groundNode.size.height) * tileMap.yScale
                let playerY = player.position.y - player.size.height / 3
                
                groundNode.isBodyActivated = playerY > groundY
            }
        }
    }
}

extension GameScene: SKPhysicsContactDelegate{
    
    func didBegin(_ contact: SKPhysicsContact) {
        let contactMask = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        switch contactMask{
        case GameConstants.PhysicsCategories.playerCategorie | GameConstants.PhysicsCategories.groundCategorie:
            player.airborne = false
            brake = false
            
        case GameConstants.PhysicsCategories.playerCategorie | GameConstants.PhysicsCategories.finishCategorie:
            gameState = .finished
            
        default:
            break
        }
    }
    
    func didEnd(_ contact: SKPhysicsContact) {
        let contactMask = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        switch contactMask{
        case GameConstants.PhysicsCategories.playerCategorie | GameConstants.PhysicsCategories.groundCategorie:
            player.airborne = true
        default:
            break
        }
    }
    
}

