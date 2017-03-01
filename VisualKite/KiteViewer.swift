//
//  KiteViewer.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-02-28.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import Cocoa
import RxSwift
import SceneKit

final class KiteAnalyser {
    private var positions = [(pos: Vector, time: Date)]()
    private var attitudes = [(att: Vector, time: Date)]()
    
    public let tetherPoint = PublishSubject<Vector>()
    public let turningPoint = PublishSubject<Vector>()
    
    public func addPosition(pos: Vector, time: Date) {
        
    }
    
    public func addAttitude(att: Vector, time: Date) {
        
    }
}

final class KiteViewer {
    // Public Variables - Mandatory Input

    public let position = Variable<Vector>(.origin)
    public let attitude = Variable<Vector>(.origin)
    
    // Public Variables - Optional Input

    public let tetherPoint = Variable<Vector?>(nil)
    public let turningPoint = Variable<Vector?>(nil)
    public let phiWind = Variable<Scalar?>(nil)

    // Private Variables

    private let bag = DisposeBag()
    private let scene = SCNScene(named: "art.scnassets/ship.scn")!
    
    // Private Variables - Nodes
    
    private let tetherPointBall = KiteViewer.makeBall(color: .orange)
    private let tetherLine = KiteViewer.makeLine(color: .orange)
    private let turningPointBall = KiteViewer.makeBall(color: .purple)
    private let eπyAxis = KiteViewer.makeArrow(color: .green, length: 1)
    private let eπzAxis = KiteViewer.makeArrow(color: .blue, length: 1)
    private let axes = KiteViewer.makeFixedAxes()
    private let windArrows = KiteViewer.makeWindArrows()
    
//    private
    let ship: SCNNode
    
    public init() {
        // Ship
        ship = scene.rootNode.childNode(withName: "ship", recursively: true)!
//        ship.scale = 0.2*Vector(1, 1, 1)
        ship.pivot = Matrix(rotation: .ez, by: -π/2)*Matrix(rotation: .ex, by: -π/2)*Matrix(scale: 5*Vector(1, 1, 1))
        
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
        [axes, tetherPointBall, tetherLine, turningPointBall, eπyAxis, eπzAxis, windArrows].forEach(scene.rootNode.addChildNode)
        
        Observable.combineLatest(position.asObservable(), attitude.asObservable(), tetherPoint.asObservable(), turningPoint.asObservable(), phiWind.asObservable(), resultSelector: noOp)
            .subscribe(onNext: updateScene)
            .disposed(by: bag)
    }
    
    // Public Methods - Setup

    public func setup(with sceneView: SCNView) {
        sceneView.scene = scene
    }
    
    // Helper Methods - Updating

    private func updateScene(p: Vector, a: Vector, o: Vector?, c: Vector?, w: Scalar?) {
        print("p: \(p.description), a: \(a.description), o:\(o?.description ?? "nil"), c:\(c?.description ?? "nil"), w:\(w?.description ?? "nil") ")
        
        print("Attitude: roll: \(a.x/π), pitch: \(a.y/π), yaw: \(a.z/π)")
        
        let roll = Matrix(rotation: .ex, by: a.x)
        let pitch = Matrix(rotation: .ey, by: a.y)
        let yaw = Matrix(rotation: .ez, by: a.z)
        let translation = Matrix(translation: p)
        
        ship.transform = roll*pitch*yaw*translation
//        ship.position = p
//        ship.eulerAngles = a
        
        if let c = c {
            turningPointBall.position = c
            
            if let w = w {
                let wind = Vector.ex.rotated(around: .ez, by: w)
                windArrows.position = c - 3*wind
                windArrows.rotation = Rotation(around: .ez, by: w)
            }
        }
        
        if let o = o {
            tetherPointBall.position = o
            update(line: tetherLine, from: o, to: p)
            
            if let c = c {
                let e_c = (c - o).unit
                let e_πy = (Vector.ez×e_c).unit
                let e_πz = e_c×e_πy
                
                update(arrow: eπzAxis, at: c, direction: e_πz)
                update(arrow: eπyAxis, at: c, direction: e_πy)
            }
        }
        
        let (lacksC, lacksO, lacksW) = (c == nil, o == nil, w == nil)
        
        turningPointBall.isHidden = lacksC
        tetherPointBall.isHidden = lacksO
        tetherLine.isHidden = lacksO
        
        eπzAxis.isHidden = lacksC || lacksO
        eπyAxis.isHidden = lacksC || lacksO
        
        windArrows.isHidden = lacksW
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
        arrow.transform = Matrix(rotation: rotationAxis, by: rotationAngle, translation: a + 1/2*e)
    }
    
    // Help\er Methods - Setup
    
    private static func makeFixedAxes() -> SCNNode {
        let length: Scalar = 10
        
        let x = makeArrow(color: .red, length: length)
        x.transform = Matrix(rotation: .ez, by: -π/2, translation: length/2*Vector.ex)
        
        let y = makeArrow(color: .green, length: length)
        y.transform = Matrix(translation: length/2*Vector.ey)
        
        let z = makeArrow(color: .blue, length: length)
        z.transform = Matrix(rotation: .ex, by: π/2, translation: length/2*Vector.ez)
        
        let node = SCNNode()
        [x, y, z].forEach(node.addChildNode)
        
        return node
    }
    
    private static func makeWindArrows() -> SCNNode {
        let length: Scalar = 5
        
        let node = SCNNode()

        for z in -1...1 {
            for y in -1...1 {
                let arrow = makeArrow(color: .white, length: length)
                let offset = Scalar(z)*Vector.ez + Scalar(y)*Vector.ey
                arrow.transform = Matrix(rotation: .ez, by: -π/2, translation: -length/2*Vector.ex + offset.rotated(around: .ex, by: π/4))
                node.addChildNode(arrow)
            }
        }
        
        return node
    }
    
    private static func makeBall(color: NSColor) -> SCNNode {
        let b = SCNSphere(radius: 0.2)
        b.materials.first?.diffuse.contents = color
        
        return SCNNode(geometry: b)
    }
    
    private static func makeArrow(color: NSColor, length: Scalar) -> SCNNode {
        let coneHeight: Scalar = 0.1
        let cylinder = SCNCylinder(radius: 0.05, height: length - coneHeight)
        cylinder.materials.first?.diffuse.contents = color
        let node = SCNNode(geometry: cylinder)
        
        let cone = SCNCone(topRadius: 0, bottomRadius: coneHeight, height: coneHeight)
        cone.materials.first?.diffuse.contents = color
        let coneNode = SCNNode(geometry: cone)
        coneNode.position = (length - coneHeight)/2*Vector.ey
        node.addChildNode(coneNode)
        
        return node
    }
    
    private static func makeLine(color: NSColor) -> SCNNode {
        let cylinder = SCNCylinder(radius: 0.05, height: 1)
        cylinder.materials.first?.diffuse.contents = color
        
        return SCNNode(geometry: cylinder)
    }
}

