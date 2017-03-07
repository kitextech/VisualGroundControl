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

enum ViewerElement {
    case kiteAxes
    case piAxes
    case piPlane
    
    case kite
    case tether

    case velocity
    case wind
}

private let baseLength: Scalar = 10

final class KiteViewer {
    // Public Variables - Visible Elements
    
    // Public Variables - Mandatory Input

    public let position = Variable<Vector>(.origin)
    public let velocity = Variable<Vector>(.origin)
    public let attitude = Variable<Matrix>(.id)
    
    public let wind = Variable<Vector>(.origin)
    
    // Public Variables - Optional Input

    public let tetherPoint = Variable<Vector>(.origin)
    public let turningPoint = Variable<Vector>(e_x)

    // Private Variables

    private let bag = DisposeBag()
    private let scene = SCNScene(named: "art.scnassets/ship.scn")!
    
    // Private Variables - Nodes
    
    private let kite: SCNNode

    private let mainAxes = KiteViewer.makeAxes(length: 50)
    private let windArrows = KiteViewer.makeWindArrows()

    private let kiteAxes = KiteViewer.makeAxes(length: 10)

    private let piAxes = KiteViewer.makeAxes(length: 10)
    private let piPlane = KiteViewer.makePlane(color: .white, side: 30)
    
    private let turningPointBall = KiteViewer.makeBall(color: .orange)

    private let tetherLine = KiteViewer.makeLine(color: .orange)
    private let tetherPointBall = KiteViewer.makeBall(color: .orange)
    
    private let velocityArrow = KiteViewer.makeArrow(color: .gray, length: baseLength)

    private let windArrow = KiteViewer.makeArrow(color: .white, length: baseLength)
    private let velocityInducedWindArrow = KiteViewer.makeArrow(color: .white, length: baseLength)
    private let apparentWindArrow = KiteViewer.makeArrow(color: .yellow, length: baseLength)
    
    private var visibleElements: Set<ViewerElement> = []

    public init() {
        scene.isPaused = false
        
        // Ship
        kite = scene.rootNode.childNode(withName: "ship", recursively: true)!
        kite.pivot = Matrix(rotation: e_x, by: -π/2)*Matrix(rotation: e_y, by: -π/2)
        
        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 200
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
        let axes = [mainAxes, kiteAxes, piAxes, piPlane]
        let arrows = [velocityArrow, windArrows, windArrow, velocityInducedWindArrow, apparentWindArrow]
        let misc = [turningPointBall, tetherLine, tetherPointBall]
        (axes + arrows + misc).forEach(scene.rootNode.addChildNode)
        
        Observable.combineLatest(position.asObservable(), velocity.asObservable(), attitude.asObservable(), wind.asObservable(), tetherPoint.asObservable(), turningPoint.asObservable(), resultSelector: ignore)
            .subscribe(onNext: updateScene)
            .disposed(by: bag)
    }
    
    // Public Methods

    public func setup(with sceneView: SCNView) {
        sceneView.scene = scene
    }
    
    public func changeVisibility(turnOn: Bool, element: ViewerElement) {
        if turnOn {
            visibleElements.insert(element)
        }
        else {
            visibleElements.remove(element)
        }
        
        updateScene()
    }
    
    public func updateScene() {
        let p = position.value
        let v = velocity.value
        let a = attitude.value
        let w = wind.value
        let o = tetherPoint.value
        let c = turningPoint.value
        
//        print("p: \(p), a: \(a), w: \(w), c: \(c) ")
        
        if shouldShow(.kite) {
            kite.transform = a.scaled(2).translated(p)
        }
        
        if shouldShow(.kiteAxes) {
            kiteAxes.transform = a.translated(p)
        }
        
        if shouldShow(.velocity) {
            update(line: velocityArrow, from: p, to: p + v)
        }
        
        let showWind = w.norm > 0 && shouldShow(.wind)
        
        if showWind {
            update(line: windArrow, from: p, to: p + w)
            update(line: velocityInducedWindArrow, from: p, to: p - v)
            update(line: apparentWindArrow, from: p, to: p + w - v)
            
            let e_w = w.unit
            windArrows.rotation = Rotation(around: e_x×e_w, by: e_x.angle(to: e_w))
        }
        
        let showTether = shouldShow(.tether)
        if showTether {
            tetherPointBall.position = o
            update(line: tetherLine, from: o, to: p)
        }
        
        // Pi axes, pi plane
        let e_c = (c - o).unit
        let e_πy = (e_z×e_c).unit
        let e_πz = e_c×e_πy
        
        let piRotation = Matrix(vx: e_c, vy: e_πy, vz: e_πz)
        
        if shouldShow(.piAxes) {
            piAxes.transform = piRotation.translated(c)
        }

        if shouldShow(.piPlane) {
            piPlane.transform = piRotation.translated(c)
        }

        turningPointBall.position = c

        // Hide certain elements

        kite.isHidden = !shouldShow(.kite)
        kiteAxes.isHidden = !shouldShow(.kiteAxes)
        velocityArrow.isHidden = !shouldShow(.velocity)
        
        windArrow.isHidden = !showWind
        velocityInducedWindArrow.isHidden = !showWind
        apparentWindArrow.isHidden = !showWind
        windArrows.isHidden = !showWind
        
        tetherPointBall.isHidden = !showTether
        tetherLine.isHidden = !showTether
        
        piAxes.isHidden = !shouldShow(.piAxes)
        piPlane.isHidden = !shouldShow(.piPlane)
    }
    
    // Helper Methods - Updating

    private func update(line: SCNNode, from a: Vector, to b: Vector) {
        let vector = b - a
        
        guard vector.norm > 0 else {
            line.transform = Matrix(scale: Vector(1, 0, 1))
            return
        }
        
        let rotationAxis = e_y×vector.unit
        let rotationAngle = vector.angle(to: .ey)
        line.transform = Matrix(rotation: rotationAxis, by: rotationAngle, translation: a, scale: Vector(1, vector.norm/baseLength, 1))
    }
    
//    private func update(arrow: SCNNode, at a: Vector, direction: Vector) {
//        let e = direction.unit
//        let rotationAxis = e_y×e
//        let rotationAngle = e.angle(to: .ey)
//        arrow.transform = Matrix(rotation: rotationAxis, by: rotationAngle, translation: a + 1/2*e)
//    }
    
    // Helper Methods - Setup
    
    private static func makeAxes(length: Scalar) -> SCNNode {
        let x = makeArrow(color: .red, length: length)
        x.transform = Matrix(rotation: .ez, by: -π/2)
        
        let y = makeArrow(color: .green, length: length)
        
        let z = makeArrow(color: .blue, length: length)
        z.transform = Matrix(rotation: .ex, by: π/2)
        
        let node = SCNNode()
        [x, y, z].forEach(node.addChildNode)
        
        return node
    }
    
    private static func makeWindArrows() -> SCNNode {
        let length: Scalar = 30
        let distance: Scalar = 20
        let spacing: Scalar = 10
        let n = 3
    
        let node = SCNNode()
        
        for y in -n...n {
            for z in -n...n {
                let arrow = makeArrow(color: .lightGray, length: length)
                let offset = spacing*(Scalar(y)*e_y + Scalar(z)*e_z)
                arrow.transform = Matrix(rotation: .ez, by: -π/2, translation: -(distance + length)*e_x + offset.rotated(around: .ex, by: π/4))
                node.addChildNode(arrow)
            }
        }
        
        return node
    }
    
    private static func makeBall(color: NSColor) -> SCNNode {
        let b = SCNSphere(radius: 1)
        b.materials.first?.diffuse.contents = color
        
        return SCNNode(geometry: b)
    }
    
    private static func makeArrow(color: NSColor, length: Scalar) -> SCNNode {
        let node = SCNNode()
        
        let coneHeight: Scalar = 1
        let cylinder = SCNCylinder(radius: 0.3, height: length - coneHeight)
        cylinder.materials.first?.diffuse.contents = color
        let cylinderNode = SCNNode(geometry: cylinder)
        cylinderNode.position = (length - coneHeight)/2*e_y
            
        node.addChildNode(cylinderNode)
        
        let cone = SCNCone(topRadius: 0, bottomRadius: coneHeight/2, height: coneHeight)
        cone.materials.first?.diffuse.contents = color
        let coneNode = SCNNode(geometry: cone)
        coneNode.position = (length - coneHeight/2)*e_y
        node.addChildNode(coneNode)
        
        return node
    }
    
    private static func makeLine(color: NSColor) -> SCNNode {
        let cylinder = SCNCylinder(radius: 0.5, height: baseLength)
        cylinder.materials.first?.diffuse.contents = color
        let node = SCNNode(geometry: cylinder)
        node.pivot = Matrix(translation: -baseLength/2*e_y)
        
        return node
    }
    
    private static func makePlane(color: NSColor, side: Scalar) -> SCNNode {
        let plane = SCNBox(width: side, height: side, length: 0.1, chamferRadius: 0)
        plane.materials.first?.diffuse.contents = color
        let node = SCNNode(geometry: plane)
        
        node.pivot = Matrix(rotation: e_y, by: π/2)
        return node
    }
    
    // Helper Methods - Misc

    private func shouldShow(_ element: ViewerElement) -> Bool {
        return visibleElements.contains(element)
    }
}

//        let roll = Matrix(rotation: e_y, by: a.x)
//        let pitch = Matrix(rotation: e_z, by: a.y)
//        let yaw = Matrix(rotation: e_x, by: a.z)
//        let translation = Matrix(translation: p)
//
//        ship.transform = SCNMatrix4Scale(yaw*pitch*roll*translation, 0.2, 0.2, 0.2)


//        kite.position = p

//        let yaw = π + π/2 + atan2(-apparent.x, apparent.y)
//        let pitch = atan2(apparent.z, sqrt(apparent.x*apparent.x + apparent.y*apparent.y))
//        let pitch = atan2(apparent.z, apparent.y)

//        let a = Vector(roll, pitch, yaw)
//        let a = Vector(a.x, a.y, a.z)
//        let a = Vector(a.x + π/2, pitch, a.z)
//        ship.eulerAngles = a

