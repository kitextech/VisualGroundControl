//
//  GameViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-02-25.
//  Copyright (c) 2017 Gustaf Kugelberg. All rights reserved.
//

import SceneKit
import QuartzCore

class GameViewController: NSViewController {
    
    @IBOutlet weak var gameView: GameView!
    @IBOutlet weak var vSlider: NSSlider!
    @IBOutlet weak var hSlider: NSSlider!
    
    let kite = KiteEmulator()
    
    var cBall: SCNNode!
    var c2Ball: SCNNode!
    
    var cAxis: SCNNode!
    
    var eπxAxis: SCNNode!
    var eπyAxis: SCNNode!

    var c2Axis: SCNNode!
    
    override func awakeFromNib(){
        super.awakeFromNib()
        
        vSlider.minValue = Double(0)
        vSlider.maxValue = Double(π/2)
        
        hSlider.minValue = Double(-π)
        hSlider.maxValue = Double(π)
        
        // create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // create and add a camera to the scene
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        
        // place the camera
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)
        
        // create and add a light to the scene
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = NSColor.darkGray
        scene.rootNode.addChildNode(ambientLightNode)
        
        // retrieve the ship node
//        let ship = scene.rootNode.childNode(withName: "ship", recursively: true)!
        
        // animate the 3d object
//        let animation = CABasicAnimation(keyPath: "rotation")
//        animation.toValue = NSValue(scnVector4: SCNVector4(x: CGFloat(0), y: CGFloat(1), z: CGFloat(0), w: CGFloat(M_PI)*2))
//        animation.duration = 3
//        animation.repeatCount = MAXFLOAT //repeat forever
//        ship.addAnimation(animation, forKey: nil)

        // set the scene to the view
        gameView.scene = scene
        
        // allows the user to manipulate the camera
        gameView.allowsCameraControl = true
        
        // show statistics such as fps and timing information
        gameView.showsStatistics = true
        
        // configure the view
        gameView.backgroundColor = .black
        
        addAxes()
        
        func ball(at pos: Vector, color: NSColor) -> SCNNode {
            let b = SCNSphere(radius: 0.2)
            b.materials.first?.diffuse.contents = color
            let node = SCNNode(geometry: b)
            node.position = pos
            return node
        }
        
        cBall = ball(at: kite.c, color: .purple)
        gameView.scene!.rootNode.addChildNode(cBall)

        c2Ball = ball(at: kite.c2, color: .orange)
        gameView.scene!.rootNode.addChildNode(c2Ball)

        updateBall()

//        let base = 11*Vector.ex
//        let root = gameView.scene!.rootNode
//        
//        for i in 0...5 {
//            let rho = Scalar(i)/5
//            let phi = rho*π/2
//            let pos = Matrix.rotation(around: .ez, by: phi)*base
//            let color = NSColor(red: 1 - rho, green: rho, blue: 0, alpha: 1)
//            let b = ball(at: pos, color: color)
//            root.addChildNode(b)
//        }
    }
    
    func axis(color: NSColor, length: Scalar) -> SCNNode {
        let cylinder = SCNCylinder(radius: 0.05, height: length)
        cylinder.materials.first?.diffuse.contents = color
        let node = SCNNode(geometry: cylinder)
        
        let cone = SCNCone(topRadius: 0, bottomRadius: 0.1, height: 0.1)
        cone.materials.first?.diffuse.contents = color
        let coneNode = SCNNode(geometry: cone)
        coneNode.position = length/2*Vector.ey
        node.addChildNode(coneNode)
        
        return node
    }

    func addAxes() {
        let length: Scalar = 10

        let x = axis(color: .red, length: length)
        x.transform = Matrix(rotation: .ez, by: -π/2, translation: length/2*Vector.ex)
        gameView.scene?.rootNode.addChildNode(x)
    
        let y = axis(color: .green, length: length)
        y.transform = Matrix(translation: length/2*Vector.ey)

        gameView.scene?.rootNode.addChildNode(y)

        let z = axis(color: .blue, length: length)
//        z.transform = Matrix.rotation(around: .ex, by: π/2).translated(by: length/2*Vector.ez)
        z.transform = Matrix(rotation: .ex, by: π/2, translation: length/2*Vector.ez)

        gameView.scene?.rootNode.addChildNode(z)
    }
    
    @IBAction func vSliderChanged(_ sender: NSSlider) {
        kite.gamma = Scalar(sender.doubleValue)
        print("gamma:\(kite.gamma) -> theta: \(π/2 - kite.gamma)")

        updateBall()
    }
    
    @IBAction func hSliderChanged(_ sender: NSSlider) {
        kite.phi = Scalar(sender.doubleValue)
        print("phi:\(kite.phi)")

        updateBall()
    }
    
    private func updateBall() {
        kite.update()
        cBall.position = kite.c
        c2Ball.position = kite.c2
    }
}

let π = Scalar(M_PI)

final class KiteEmulator {
    // MARK: Input Variables
    
    public var gamma: Scalar = 0
    public var phi: Scalar = 0
    public var l: Scalar = 10
    public var r: Scalar = 0
    
    // MARK: Computed Intermediate Variables
    
    private var theta: Scalar { return π/2 - gamma }
    private var d: Scalar { return sqrt(l*l - r*r) }

    // MARK: Stored Intermediate Variables

    public var c = Vector()
    public var c2 = Vector()

    private var m_phi = Matrix()
    private var m_theta = Matrix()
    private var m_rho = Matrix()
    
    private var e_πx = Vector()
    private var e_πy = Vector()
    
    // MARK: Ouput Variables
    
    public var pos = Vector(0, 0, 0)
    public var att = Vector4(0, 0, 0, 0)
    
    public func update() {
        m_phi = Matrix(rotation: .ez, by: phi)
        m_theta = Matrix(rotation: .ey, by: theta)
        
        c = m_phi*(m_theta*(d*Vector.ez))
        
//        e_πx = 
        
//        c2 = c +
        
        print("====================")
        print("c:  " + c.description)
//        print("m2: " + m2.description)
        print("c2: " + c2.description)
    }
}






