//
//  GameViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-02-25.
//  Copyright (c) 2017 Gustaf Kugelberg. All rights reserved.
//

import SceneKit
import QuartzCore
import RxSwift
import RxCocoa

class KiteAnalyser {
    private var positions = [(pos: Vector, time: Date)]()
    private var attitudes = [(att: Vector, time: Date)]()
    
    public let calculatedTetherPoint = PublishSubject<Vector>()
    public let calculatedTurningPoint = PublishSubject<Vector>()
    
    public func addPosition(pos: Vector, time: Date) {
        
    }
    
    public func addAttitude(att: Vector, time: Date) {
        
    }
}

class KiteViewer {
//    public let tetherPoint = Variable(Vector())
//    public let c = Variable(Vector())

    public let position = Variable(Vector())
    public let attitude = Variable(Vector())
    
    private let bag = DisposeBag()

    init(view: SCNView) {
        
    }
    
    
}

class GameViewController: NSViewController {
    
    @IBOutlet weak var gameView: GameView!
    @IBOutlet weak var vSlider: NSSlider!
    @IBOutlet weak var hSlider: NSSlider!
    @IBOutlet weak var phaseSlider: NSSlider!
    @IBOutlet weak var windSlider: NSSlider!
    
    private let bag = DisposeBag()
    private let kite = KiteEmulator()
    
    var cBall: SCNNode!
    var cAxis: SCNNode!
    
    var eπzAxis: SCNNode!
    var eπyAxis: SCNNode!

    var kiteAxis: SCNNode!
    var kiteLine: SCNNode!
    
    var ship: SCNNode!
    
    let cameraNode = SCNNode()

    override func awakeFromNib(){
        super.awakeFromNib()
        
        vSlider.minValue = Double(0)
        vSlider.maxValue = Double(π/2)
        
        hSlider.minValue = Double(-π)
        hSlider.maxValue = Double(π)
        
        phaseSlider.minValue = Double(0)
        phaseSlider.maxValue = Double(2*π)

        windSlider.minValue = Double(-π)
        windSlider.maxValue = Double(π)

        // create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // create and add a camera to the scene
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        
        // place the camera
        cameraNode.position = SCNVector3(x: 15, y: 15, z: 5)
        cameraNode.eulerAngles = Vector(1.45, 0, 3*π/4)
        
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
        ship = scene.rootNode.childNode(withName: "ship", recursively: true)!
        ship.scale = 0.3*Vector(1, 1, 1)
        ship.eulerAngles = Vector(0, 0, 3*π/4)
        
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
        
        func ball(color: NSColor) -> SCNNode {
            let b = SCNSphere(radius: 0.2)
            b.materials.first?.diffuse.contents = color
            return SCNNode(geometry: b)
        }
        
        func add(_ node: SCNNode) {
            gameView.scene!.rootNode.addChildNode(node)
        }
        
        // Fixed axes
        let length: Scalar = 10
        
        let x = arrow(color: .red, length: length)
        x.transform = Matrix(rotation: .ez, by: -π/2, translation: length/2*Vector.ex)
        add(x)
        
        let y = arrow(color: .green, length: length)
        y.transform = Matrix(translation: length/2*Vector.ey)
        add(y)
        
        let z = arrow(color: .blue, length: length)
        z.transform = Matrix(rotation: .ex, by: π/2, translation: length/2*Vector.ez)
        add(z)

        // Moving objects and axes

        cBall = ball(color: .purple)
        add(cBall)
        
        cAxis = line(color: .gray)
        add(cAxis)

        eπyAxis = arrow(color: .green, length: 1)
        add(eπyAxis)

        eπzAxis = arrow(color: .blue, length: 1)
        add(eπzAxis)

        kiteAxis = line(color: .gray)
        add(kiteAxis)
        
        kiteLine = line(color: .orange)
        add(kiteLine)
        
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
        
        phaseSlider.rx.value
            .map(Scalar.init(_:))
            .bindTo(kite.phase)
            .disposed(by: bag)
        
        // ----
        
        PublishSubject.combineLatest(kite.kitePos, kite.kiteAtt, resultSelector: { $0 })
            .bindNext(updateScene)
            .disposed(by: bag)
    }
    
    // MARK: - Helper Methods
    
    private func arrow(color: NSColor, length: Scalar) -> SCNNode {
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
    
    private func line(color: NSColor) -> SCNNode {
        let cylinder = SCNCylinder(radius: 0.05, height: 1)
        cylinder.materials.first?.diffuse.contents = color
        return SCNNode(geometry: cylinder)
    }

    @IBAction func vSliderChanged(_ sender: NSSlider) {
        kite.gamma = Scalar(sender.doubleValue)
        print("gamma:\(kite.gamma) -> theta: \(π/2 - kite.gamma)")

//        updateScene()
    }
    
    @IBAction func hSliderChanged(_ sender: NSSlider) {
//        cameraNode.eulerAngles.y = Scalar(sender.doubleValue)
//        print("euler_1:\(cameraNode.eulerAngles.y)")
//        return

        kite.phi = Scalar(sender.doubleValue)
        print("phi:\(kite.phi)")

//        updateScene()
    }
    
    private func updateScene(kitePos: Vector, kiteAtt: Vector) {
        update(line: cAxis, from: .origin, to: kite.debug_c)
        cBall.position = kite.debug_c
        
        update(line: kiteAxis, from: kite.debug_c, to: kite.pos)
        ship.position = kitePos
        ship.eulerAngles = kiteAtt

        update(line: kiteLine, from: .origin, to: kitePos)

        update(arrow: eπzAxis, at: kite.debug_c, direction: kite.debug_e_πz)
        update(arrow: eπyAxis, at: kite.debug_c, direction: kite.debug_e_πy)
    }
    
    private func update(line: SCNNode, from a: Vector, to b: Vector) {
        let vector = b - a
        let rotationAxis = Vector.ey×vector.unit
        let rotationAngle = vector.angle(with: .ey)
        line.transform = Matrix(rotation: rotationAxis, by: rotationAngle, translation: a + 1/2*vector, scale: Vector(1, vector.norm, 1))
    }
    
    private func update(arrow: SCNNode, at a: Vector, direction: Vector) {
        let e = direction.unit
        let rotationAxis = Vector.ey×e
        let rotationAngle = e.angle(with: .ey)
        arrow.transform = Matrix(rotation: rotationAxis, by: rotationAngle, translation: a + 1/2*direction)
    }
}

let π = Scalar(M_PI)

final class KiteEmulator {
    private let bag = DisposeBag()

    // MARK: Input Variables
    
    public var gamma: Scalar = 0
    public var phi: Scalar = 0
    public var l: Scalar = 10
    public var r: Scalar = 3
    
    public let phase = Variable(Scalar())
    
    public let phiWind = Variable(Scalar())

    // MARK: Intermediate Variables
    
    // Computed
    
    private var theta: Scalar { return π/2 - gamma }
    private var d: Scalar { return sqrt(l*l - r*r) }

    // Stored

    private var m_phi = Matrix()
    private var m_theta = Matrix()
    private var m_rho = Matrix()

    private var c = Vector()
    private var e_πz = Vector()
    private var e_πy = Vector()

    // Debug
    
    public var debug_c: Vector { return c }
    public var debug_e_πz: Vector { return e_πz }
    public var debug_e_πy: Vector { return e_πy }
    
    // MARK: Ouput Variables
    
    public var pos = Vector(0, 0, 0)
    public var att = Vector(0, 0, 0)
    
    public let kitePos = PublishSubject<Vector>()
    public let kiteAtt = PublishSubject<Vector>()
    
    public init() {
        update(phase: phase.value)
        
        phase.asDriver()
            .drive(onNext: update)
            .disposed(by: bag)
    }
    
    public func update(phase: Scalar) {
        m_phi = Matrix(rotation: .ez, by: phi)
        m_theta = Matrix(rotation: .ey, by: theta)
        
        c = (d*Vector.ez).transformed(by: m_theta).transformed(by: m_phi)
        
        e_πz = (-Vector.ex).transformed(by: m_theta).transformed(by: m_phi)
        e_πy = Vector.ey.transformed(by: m_theta).transformed(by: m_phi)
        
        pos = c + r*e_πy.rotated(around: c, by: phase)
        att = Vector(0, -phase, 3*π/4)
        
        print("====================")
        print("c:  " + c.description)
        
        kitePos.onNext(pos)
        kiteAtt.onNext(att)
    }
}






