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
    public let attitude = Variable<Vector>(.ez)
    
    // Public Variables - Optional Input

    public let tetherPoint = Variable<Vector?>(nil)
    public let turningPoint = Variable<Vector?>(nil)
    public let phiWind = Variable<Scalar?>(nil)

    // Private Variables

    private let bag = DisposeBag()
    private let scene = SCNScene(named: "art.scnassets/ship.scn")!
    
    // Private Variables - Nodes
    
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
        
        Observable.combineLatest(position.asObservable(), attitude.asObservable(), resultSelector: supplyExtraValues)
            .subscribe(onNext: updateScene)
            .disposed(by: bag)
    }
    
    // Public Methods - Setup

    public func setup(with sceneView: SCNView) {
        sceneView.scene = scene
    }
    
    // Helper Methods - Updating

    private func supplyExtraValues(pos: Vector, att: Vector) -> (Vector, Vector, Vector?, Vector?, Scalar?) {
        return (pos, att, tetherPoint.value, turningPoint.value, phiWind.value)
    }

    
    private func update(pos: Vector, att: Vector) {
        updateScene(p: pos, a: att, o: tetherPoint.value, c: turningPoint.value, w: phiWind.value)
    }

    private func updateScene(p: Vector, a: Vector, o: Vector?, c: Vector?, w: Scalar?) -> Void {
        ship.position = p
        ship.eulerAngles = a
        
        if let c = c {
            turningPointBall.position = c
        }
        
        if let o = o {
            tetherPointBall.position = o
            update(line: tetherLine, from: o, to: p)
            
            if let c = c {
                let e_c = (c - o).unit
                let e_πy = Vector.ez×e_c
                let e_πz = e_πy×e_c
                
                update(arrow: eπzAxis, at: c, direction: e_πz)
                update(arrow: eπyAxis, at: c, direction: e_πy)
            }
        }
        
        let (hasC, hasO) = (c != nil, o != nil)
        
        turningPointBall.isHidden = hasC
        tetherPointBall.isHidden = hasO
        tetherLine.isHidden = hasO
        
        eπzAxis.isHidden = hasC && hasO
        eπyAxis.isHidden = hasC && hasO
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
    
    // Help\er Methods - Setup
    
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

