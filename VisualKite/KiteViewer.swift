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
    public let velocity = Variable<Vector>(.origin)
    public let attitude = Variable<Vector>(.origin)
    public let wind = Variable<Vector>(.origin)
    
    // Public Variables - Optional Input

    public let tetherPoint = Variable<Vector?>(nil)
    public let turningPoint = Variable<Vector?>(nil)

    // Private Variables

    private let bag = DisposeBag()
    private let scene = SCNScene(named: "art.scnassets/ship.scn")!
    
    // Private Variables - Nodes
    
    private let tetherPointBall = KiteViewer.makeBall(color: .orange)
    private let tetherLine = KiteViewer.makeLine(color: .orange)
    private let turningPointBall = KiteViewer.makeBall(color: .orange)
    private let eπyAxis = KiteViewer.makeArrow(color: .green, length: 1)
    private let eπzAxis = KiteViewer.makeArrow(color: .blue, length: 1)
    private let axes = KiteViewer.makeFixedAxes()
    private let windArrows = KiteViewer.makeWindArrows()
    
    private let velocityArrow = KiteViewer.makeArrow(color: .gray, length: 1)
    private let velocityWindArrow = KiteViewer.makeArrow(color: .white, length: 1)
    private let windArrow = KiteViewer.makeArrow(color: .white, length: 1)
    private let apparentWindArrow = KiteViewer.makeArrow(color: .yellow, length: 1)

    private let sxAxis = KiteViewer.makeArrow(color: .red, length: 1)
    private let syAxis = KiteViewer.makeArrow(color: .green, length: 1)
    private let szAxis = KiteViewer.makeArrow(color: .blue, length: 1)

    
    private let ship: SCNNode
    
    public init() {
        // Ship
        ship = scene.rootNode.childNode(withName: "ship", recursively: true)!
        ship.pivot = Matrix(rotation: e_x, by: -π/2)*Matrix(rotation: e_y, by: -π/2)
        
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
        let nodes = [axes, tetherPointBall, tetherLine, turningPointBall, eπyAxis, eπzAxis, windArrows, windArrow, velocityWindArrow, apparentWindArrow]
        nodes.forEach(scene.rootNode.addChildNode)
        
        [sxAxis, syAxis, szAxis].forEach(scene.rootNode.addChildNode)
        
        Observable.combineLatest(position.asObservable(), velocity.asObservable(), attitude.asObservable(), wind.asObservable(), tetherPoint.asObservable(), turningPoint.asObservable(), resultSelector: noOp)
            .subscribe(onNext: updateScene)
            .disposed(by: bag)
    }
    
    // Public Methods - Setup

    public func setup(with sceneView: SCNView) {
        sceneView.scene = scene
    }
    
    // Helper Methods - Updating

    private func updateScene(p: Vector, v: Vector, a: Vector, w: Vector, o: Vector?, c: Vector?) {
        //        print("p: \(p), a: \(a), w: \(w), o: \(o?.description ?? "nil"), c: \(c?.description ?? "nil") ")
//        print("Euler/π: {\(a.x/π), \(a.y/π), \(a.z/π)}")

        let (lacksC, lacksO, lacksW) = (c == nil, o == nil, w.norm == 0)
        
//        let roll = Matrix(rotation: e_y, by: a.x)
//        let pitch = Matrix(rotation: e_z, by: a.y)
//        let yaw = Matrix(rotation: e_x, by: a.z)
//        let translation = Matrix(translation: p)
//        
//        ship.transform = SCNMatrix4Scale(yaw*pitch*roll*translation, 0.2, 0.2, 0.2)
        
        ship.transform = SCNMatrix4MakeScale(0.2, 0.2, 0.2)

        if (w - v).norm == 0 { return }
        if p.norm == 0 { return }

        let apparent = w - v
        let e_p = p.unit

        if apparent.norm == 0 { return }
        
        let sx = -apparent.unit
        let sy = -sx×e_p
        let sz = sx×sy
        
        let rotation = Matrix(vx: sx, vy: sy, vz: sz)
        
        ship.transform = SCNMatrix4Scale(rotation, 0.2, 0.2, 0.2)
        
        update(line: sxAxis, from: p, to: p + 2*sx)
        update(line: syAxis, from: p, to: p + 2*sy)
        update(line: szAxis, from: p, to: p + 2*sz)

        ship.position = p
        
//        let yaw = π + π/2 + atan2(-apparent.x, apparent.y)
//        let pitch = atan2(apparent.z, sqrt(apparent.x*apparent.x + apparent.y*apparent.y))
//        let pitch = atan2(apparent.z, apparent.y)
        
//        let a = Vector(roll, pitch, yaw)
//        let a = Vector(a.x, a.y, a.z)
//        let a = Vector(a.x + π/2, pitch, a.z)
//        ship.eulerAngles = a
        
        update(line: velocityArrow, from: p, to: p + v)
        
//        let pApparent = Vector(apparent.x, apparent.y, 0)
//        update(line: velocityArrow, from: p, to: p + 2*pApparent)

        update(line: velocityWindArrow, from: p, to: p - 2*v)
        
        if !lacksW {
            update(line: windArrow, from: p, to: p + 2*w)
            update(line: apparentWindArrow, from: p, to: p + 2*apparent)
            
            if let c = c {
                let e_w = w.unit
                windArrows.position = c
                windArrows.rotation = Rotation(around: e_x×e_w, by: e_x.angle(to: e_w))
            }
        }
        
        if let c = c {
            turningPointBall.position = c
        }
        
        if let o = o {
            tetherPointBall.position = o
            update(line: tetherLine, from: o, to: p)
        }
        
        if let c = c, let o = o {
            let e_c = (c - o).unit
            let e_πy = (e_z×e_c).unit
            let e_πz = e_c×e_πy
            
            update(arrow: eπzAxis, at: c, direction: e_πz)
            update(arrow: eπyAxis, at: c, direction: e_πy)
        }
        
        turningPointBall.isHidden = lacksC
        tetherPointBall.isHidden = lacksO
        tetherLine.isHidden = lacksO
        
        eπzAxis.isHidden = lacksC || lacksO
        eπyAxis.isHidden = lacksC || lacksO
        
        windArrows.isHidden = lacksW
        windArrow.isHidden = lacksW
        apparentWindArrow.isHidden = lacksW
    }
    
    private func update(line: SCNNode, from a: Vector, to b: Vector) {
        let vector = b - a
        
        guard vector.norm > 0 else {
            line.transform = Matrix(scale: Vector(1, 0, 1))
            return
        }
        
        let rotationAxis = e_y×vector.unit
        let rotationAngle = vector.angle(to: .ey)
        line.transform = Matrix(rotation: rotationAxis, by: rotationAngle, translation: a + 1/2*vector, scale: Vector(1, vector.norm, 1))
    }
    
    private func update(arrow: SCNNode, at a: Vector, direction: Vector) {
        let e = direction.unit
        let rotationAxis = e_y×e
        let rotationAngle = e.angle(to: .ey)
        arrow.transform = Matrix(rotation: rotationAxis, by: rotationAngle, translation: a + 1/2*e)
    }
    
    // Help\er Methods - Setup
    
    private static func makeFixedAxes() -> SCNNode {
        let length: Scalar = 10
        
        let x = makeArrow(color: .red, length: length)
        x.transform = Matrix(rotation: .ez, by: -π/2, translation: length/2*e_x)
        
        let y = makeArrow(color: .green, length: length)
        y.transform = Matrix(translation: length/2*e_y)
        
        let z = makeArrow(color: .blue, length: length)
        z.transform = Matrix(rotation: .ex, by: π/2, translation: length/2*e_z)
        
        let node = SCNNode()
        [x, y, z].forEach(node.addChildNode)
        
        return node
    }
    
    private static func makeWindArrows() -> SCNNode {
        let length: Scalar = 5
        let spacing: Scalar = 5
        
        let node = SCNNode()

        for y in -1...1 {
            for z in -1...1 {
                let arrow = makeArrow(color: .lightGray, length: length)
                let offset = Scalar(y)*e_y + Scalar(z)*e_z
                arrow.transform = Matrix(rotation: .ez, by: -π/2, translation: -(length/2 + spacing)*e_x + offset.rotated(around: .ex, by: π/4))
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
    
//    private static func makeWindArrow() -> SCNNode {
//        let arrow = makeArrow(color: .lightGray, length: 1)
//        arrow.pivot = Matrix(rotation: .ez, by: π/2)
//        return arrow
//    }
    
    private static func makeArrow(color: NSColor, length: Scalar) -> SCNNode {
        let coneHeight: Scalar = 0.1
        let cylinder = SCNCylinder(radius: 0.05, height: length - coneHeight)
        cylinder.materials.first?.diffuse.contents = color
        let node = SCNNode(geometry: cylinder)
        
        let cone = SCNCone(topRadius: 0, bottomRadius: coneHeight, height: coneHeight)
        cone.materials.first?.diffuse.contents = color
        let coneNode = SCNNode(geometry: cone)
        coneNode.position = (length - coneHeight)/2*e_y
        node.addChildNode(coneNode)
        
        return node
    }
    
    private static func makeLine(color: NSColor) -> SCNNode {
        let cylinder = SCNCylinder(radius: 0.05, height: 1)
        cylinder.materials.first?.diffuse.contents = color
        
        return SCNNode(geometry: cylinder)
    }
}

