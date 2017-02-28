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

//        let animation = CABasicAnimation(keyPath: "rotation")
//        animation.toValue = NSValue(scnVector4: SCNVector4(x: CGFloat(0), y: CGFloat(1), z: CGFloat(0), w: CGFloat(M_PI)*2))
//        animation.duration = 3
//        ship.addAnimation(animation, forKey: nil)

//func identity<S, T, U, V>(s: S, t: T, u: U, v: V) -> (S, T, U, V) {
//    return (s, t, u, v)
//}

//extension Observable {
//    func combineLatest() {
//        
//    }
//}

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
    public let position = Variable(Vector())
    public let attitude = Variable(Vector())
    public let tetherPoint = Variable(Vector())
    public let turningPoint = Variable(Vector())
    
    private let bag = DisposeBag()
    
    private let scene = SCNScene(named: "art.scnassets/ship.scn")!

    // Nodes
    
    private let tetherPointBall = KiteViewer.ball(color: .orange)
    private let tetherLine = KiteViewer.line(color: .orange)
    
    private let turningPointBall = KiteViewer.ball(color: .purple)
    
    private let eπyAxis = KiteViewer.arrow(color: .green, length: 1)
    private let eπzAxis = KiteViewer.arrow(color: .blue, length: 1)

    private let axes = KiteViewer.fixedAxes()

    private let ship: SCNNode
    
    public init() {
        // Ship

        ship = scene.rootNode.childNode(withName: "ship", recursively: true)!
        ship.scale = 0.3*Vector(1, 1, 1)
        ship.eulerAngles = Vector(0, 0, 3*π/4)
        
        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.position = SCNVector3(x: 15, y: 15, z: 5)
        cameraNode.eulerAngles = Vector(1.45, 0, 3*π/4)
        
        // Light
        let lightNode = SCNNode()
        let light = SCNLight()
        light.type = .omni
        lightNode.light = light
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)
        
        // Ambient Light
        let ambientLightNode = SCNNode()
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor.darkGray
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)
        
        // Nodes
        (axes + [tetherPointBall, tetherLine, turningPointBall, eπyAxis, eπzAxis]).forEach(scene.rootNode.addChildNode)
        
        //        let combo = PublishSubject<Bool>.combineLatest(position.asObservable(), attitude.asObservable(), tetherPoint.asObservable(), turningPoint.asObservable(), resultSelector: { _ in true } )
        //
        //        //            .bindNext(updateScene)
        ////            .disposed(by: bag)
    }
    
    public func setup(with sceneView: SCNView) {
        sceneView.scene = scene
    }
    
    // Updating

    private func updateScene(kitePosition p: Vector, kiteAttitude a: Vector, tetherPoint o: Vector, turningPoint c: Vector) -> Void {
        turningPointBall.position = c
        tetherPointBall.position = o
        
        ship.position = p
        ship.eulerAngles = a
        
        update(line: tetherLine, from: o, to: p)
        
        let e_c = (c - o).unit
        let e_πy = Vector.ez×e_c
        let e_πz = e_πy×e_c
        
        update(arrow: eπzAxis, at: c, direction: e_πz)
        update(arrow: eπyAxis, at: c, direction: e_πy)
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
    
    // Setup Helper Methods
    
    private static func fixedAxes() -> [SCNNode] {
        // Fixed axes
        let length: Scalar = 10
        
        let x = arrow(color: .red, length: length)
        x.transform = Matrix(rotation: .ez, by: -π/2, translation: length/2*Vector.ex)
        
        let y = arrow(color: .green, length: length)
        y.transform = Matrix(translation: length/2*Vector.ey)
        
        let z = arrow(color: .blue, length: length)
        z.transform = Matrix(rotation: .ex, by: π/2, translation: length/2*Vector.ez)

        return [x, y, z]
    }
    
    private static func ball(color: NSColor) -> SCNNode {
        let b = SCNSphere(radius: 0.2)
        b.materials.first?.diffuse.contents = color
        
        return SCNNode(geometry: b)
    }

    private static func arrow(color: NSColor, length: Scalar) -> SCNNode {
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
    
    private static func line(color: NSColor) -> SCNNode {
        let cylinder = SCNCylinder(radius: 0.05, height: 1)
        cylinder.materials.first?.diffuse.contents = color
        
        return SCNNode(geometry: cylinder)
    }
}

class GameViewController: NSViewController {
    
    @IBOutlet weak var sceneView: SCNView!
    @IBOutlet weak var vSlider: NSSlider!
    @IBOutlet weak var hSlider: NSSlider!
    @IBOutlet weak var phaseSlider: NSSlider!
    @IBOutlet weak var windSlider: NSSlider!
    
    private let bag = DisposeBag()
    private let kite = KiteEmulator()
    private let viewer = KiteViewer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewer.setup(with: sceneView)
    }
    
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
        
        phaseSlider.rx.value
            .map(Scalar.init(_:))
            .bindTo(kite.phase)
            .disposed(by: bag)
        
        // ----
        
    }
    
    // MARK: - Helper Methods
    

    @IBAction func vSliderChanged(_ sender: NSSlider) {
        kite.gamma = Scalar(sender.doubleValue)
        print("gamma:\(kite.gamma) -> theta: \(π/2 - kite.gamma)")
    }
    
    @IBAction func hSliderChanged(_ sender: NSSlider) {
//        cameraNode.eulerAngles.y = Scalar(sender.doubleValue)
//        print("euler_1:\(cameraNode.eulerAngles.y)")
//        return

        kite.phi = Scalar(sender.doubleValue)
        print("phi:\(kite.phi)")
    }
}

let π = Scalar(M_PI)

final class KiteEmulator {
    private let bag = DisposeBag()

    // MARK: Input Variables
    
    public var origin = Vector()

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
    
    private var pos = Vector(0, 0, 0)
    private var att = Vector(0, 0, 0)

    // Debug
    
    public var debug_c: Vector { return c }
    public var debug_e_πz: Vector { return e_πz }
    public var debug_e_πy: Vector { return e_πy }
    
    // MARK: Ouput Variables
    
    public let position = PublishSubject<Vector>()
    public let attitude = PublishSubject<Vector>()
    public let tetherPoint = PublishSubject<Vector>()
    public let turningPoint = PublishSubject<Vector>()
    
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
        
        position.onNext(pos)
        attitude.onNext(att)
        tetherPoint.onNext(origin)
        turningPoint.onNext(c)
    }
}






