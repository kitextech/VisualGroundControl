//
//  TraceViewsViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-18.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import RxSwift
import QuartzCore

func map<S, T>(f: @escaping (S) -> T) -> ([S]) -> [T] {
    return { $0.map(f) }
}

class TraceViewsViewController: NSViewController {
    // MARK: - Parameters

    // MARK: - Outlets

    @IBOutlet weak var xyView: TraceView!
    @IBOutlet weak var freeView: TraceView!

    @IBOutlet weak var xzButton: NSButton!
    @IBOutlet weak var yzButton: NSButton!
    @IBOutlet weak var piButton: NSButton!

    // MARK: - Private

    private let bag = DisposeBag()

    // MARK: - View Controller Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        let kite = KiteController.shared.kite0

        freeView.angles.value = (π/2 - 0.2, 0)
        freeView.scrolls = true

        let position = Variable<Vector>(.zero)
        kite.location.map(TimedLocation.getPosition).bind(to: position).disposed(by: bag)

        position.asObservable().bind(to: xyView.kitePosition).disposed(by: bag)
        position.asObservable().bind(to: freeView.kitePosition).disposed(by: bag)

        let quaternion = Variable<Quaternion>(.id)
        kite.quaternion.map(TimedQuaternion.getQuaternion).bind(to: quaternion).disposed(by: bag)

        quaternion.asObservable().bind(to: xyView.kiteOrientation).disposed(by: bag)
        quaternion.asObservable().bind(to: freeView.kiteOrientation).disposed(by: bag)

//        kite.positionB.asObservable().bind(to: xyView.bPosition).disposed(by: bag)
//        kite.positionB.asObservable().bind(to: freeView.bPosition).disposed(by: bag)

        kite.positionTarget.asObservable().bind(to: xyView.targetPosition).disposed(by: bag)
        kite.positionTarget.asObservable().bind(to: freeView.targetPosition).disposed(by: bag)

        kite.tetherLength.asObservable().bind(to: xyView.tetherLength).disposed(by: bag)
        kite.tetherLength.asObservable().bind(to: freeView.tetherLength).disposed(by: bag)

        let d = Observable.combineLatest(kite.tetherLength.asObservable(), kite.turningRadius.asObservable(), resultSelector: getD)
        let c = Observable.combineLatest(kite.phiC.asObservable(), kite.thetaC.asObservable(), d, resultSelector: getC)

        let pi = c.map(getPiPlane)

        pi.bind(to: xyView.piPlane).disposed(by: bag)
        pi.bind(to: freeView.piPlane).disposed(by: bag)

        kite.turningRadius.asObservable().bind(to: xyView.turningRadius).disposed(by: bag)
        kite.turningRadius.asObservable().bind(to: freeView.turningRadius).disposed(by: bag)

        // Trace views as controls

        xyView.requestedTargetPosition.bind(to: kite.positionTarget).disposed(by: bag)
        freeView.requestedTargetPosition.bind(to: kite.positionTarget).disposed(by: bag)

        xzButton.rx.tap.map { (0, π/2) }.bind(to: freeView.angles).disposed(by: bag)
        yzButton.rx.tap.map { (π/2, π/2) }.bind(to: freeView.angles).disposed(by: bag)
        piButton.rx.tap.map { (π + kite.phiC.value, π/2 - kite.thetaC.value) }.bind(to: freeView.angles).disposed(by: bag)
    }

    private func getD(tether: Scalar, r: Scalar) -> Scalar {
        return sqrt(tether*tether - r*r)
    }

    private func getC(phi: Scalar, theta: Scalar, d: Scalar) -> Vector {
        return Vector(phi: phi, theta: π/2 + theta, r: d)
    }

    private func getCKite(phi: Scalar, theta: Scalar, d: Scalar) -> Vector {
        let xyFactor = d*cos(theta);
        return Vector(xyFactor*cos(phi), xyFactor*sin(phi), -d*sin(theta))
    }

    private func getPiPlane(c: Vector) -> Plane {
        return Plane(center: c, normal: c.unit)
    }
}

class TraceView: NSView {
//    private var tracer = Tracer()

    public var scrolls = false

    // MARK: - Inputs
    public let kiteOrientation = Variable<Quaternion>(.id)

    public let kitePosition = Variable<Vector>(.origin)
    public let bPosition = Variable<Vector>(.origin)
    public let targetPosition = Variable<Vector>(.origin)

    public let tetherLength = Variable<Scalar>(50)

    public let piPlane = Variable<Plane>(.z)
    public let turningRadius = Variable<Scalar>(0)

    // MARK: - Output

    public let requestedTargetPosition = PublishSubject<Vector>()

    // MARK: - Parameters

    public let angles = Variable(Scalar(), Scalar())
    public let scale = Variable<Scalar>(70)

    // MARK: - Private

    public let axis = Variable<Vector>(-e_z)

    private let kitePoint = Variable<NSPoint>(.zero)
    private let bPoint = Variable<NSPoint>(.zero)
    private let cPoint = Variable<NSPoint>(.zero)
    private let targetPoint = Variable<NSPoint>(.zero)

    private let sphere = Variable<Sphere>(.unit)

    // MARK: - Visual

    private var circlePath = Variable<NSBezierPath?>(nil)
    private var spherePath = Variable<NSBezierPath?>(nil)
    private var kitePath = Variable<NSBezierPath?>(nil)

    // Actors

    private var projector = NSPoint.projector(along: -e_z)
    private var deProjector = NSPoint.deProjector(along: -e_z)

    private var upScaler = NSPoint.scaler(by: 70)
    private var downScaler = NSPoint.scaler(by: 1/70)

    private var absolutiser = NSPoint.absolutiser(in: .unit)
    private var relativiser = NSPoint.relativiser(in: .unit)

    private var spherifier: (Vector) -> Vector = noOp

    // Constants

    private let bag = DisposeBag()
    private let kite = LineArtKite(span: 1.2, length: 1, height: 0.6).scaled(s: 20)
    private let axes = [e_x, e_y, e_z].map { 40*Line(start: .origin, end: $0) }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        // Sphere

        Observable.combineLatest(bPosition.asObservable(), tetherLength.asObservable(), resultSelector: Sphere.init).bind(to: sphere).disposed(by: bag)

        // Transformers

        axis.asObservable().bind(onNext: axisChanged).disposed(by: bag)
        angles.asObservable().map(Vector.unitVector).bind(to: axis).disposed(by: bag)
        Observable.combineLatest(sphere.asObservable(), axis.asObservable(), resultSelector: noOp).bind(onNext: sphereOrAxisChanged).disposed(by: bag)
        scale.asObservable().bind(onNext: scaleChanged).disposed(by: bag)

        // Positions

        kitePosition.asObservable().map(pointify).bind(to: kitePoint).disposed(by: bag)
        bPosition.asObservable().map(pointify).bind(to: bPoint).disposed(by: bag)
        piPlane.asObservable().map(Plane.getCenter).map(pointify).bind(to: cPoint).disposed(by: bag)
        targetPosition.asObservable().map(pointify).bind(to: targetPoint).disposed(by: bag)

        // Paths

        Observable.combineLatest(kitePosition.asObservable(), kiteOrientation.asObservable(), resultSelector: kiteLines).map(makePath).bind(to: kitePath).disposed(by: bag)

        let allSphereLines = sphere.asObservable().map(sphereLines)
        let occlusionPlane = Observable.combineLatest(bPosition.asObservable(), axis.asObservable(), resultSelector: Plane.init)

        Observable.combineLatest(allSphereLines, occlusionPlane, resultSelector: occluded).map(makePath).bind(to: spherePath).disposed(by: bag)

        let allCircleLines = Observable.combineLatest(piPlane.asObservable(), turningRadius.asObservable(), resultSelector: circleLines)

        Observable.combineLatest(allCircleLines, occlusionPlane, resultSelector: occluded).map(makePath).bind(to: circlePath).disposed(by: bag)

        // Drawing

        kitePath.asObservable().bind(onNext: redraw).addDisposableTo(bag)
        spherePath.asObservable().bind(onNext: redraw).addDisposableTo(bag)

        targetPosition.asObservable().bind(onNext: redraw).addDisposableTo(bag)
        piPlane.asObservable().bind(onNext: redraw).addDisposableTo(bag)

        acceptsTouchEvents = true
    }

    // Transformers

    private func axisChanged(vector: Vector) {
        projector = NSPoint.projector(along: vector)
        deProjector = NSPoint.deProjector(along: vector)
        recalculate()
        redraw()
    }

    private func sphereOrAxisChanged(sphere: Sphere, normal: Vector) {
        spherifier = Sphere.spherifier(along: normal, on: sphere)
        redraw()
    }

    private func scaleChanged(scale: Scalar) {
        downScaler = NSPoint.scaler(by: 1/scale)
        upScaler = NSPoint.scaler(by: scale)
        recalculate()
        redraw()
    }

    private func boundsChanged(rect: NSRect) {
        absolutiser = NSPoint.absolutiser(in: rect)
        relativiser = NSPoint.relativiser(in: rect)
        redraw()
    }

    // Actions
    override func mouseDown(with event: NSEvent) {
        processMouseEvent(event)
    }

    override func mouseDragged(with event: NSEvent) {
        processMouseEvent(event)
    }

    override func scrollWheel(with event: NSEvent) {
        guard scrolls else { return }

        angles.value.0 += event.deltaX/20
        angles.value.1 -= event.deltaY/20
    }

    override func magnify(with event: NSEvent) {
        scale.value /= 1 + 0.6*event.magnification
    }

    private func processMouseEvent(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let vector = vectorify(point)
        requestedTargetPosition.onNext(spherifier(vector))
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        boundsChanged(rect: bounds)
    }

    // Drawing

    private func recalculate() {
        targetPosition.value = targetPosition.value
        kitePosition.value = kitePosition.value
        bPosition.value = bPosition.value
        piPlane.value = piPlane.value
    }

    private func redraw<T>(ignored: T) {
        redraw()
    }

    private func redraw() {
        setNeedsDisplay(bounds)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.lightGray.set()
//        path.stroke()

        let axesPaths = axes.map(makePath)
        NSColor.blue.set()
        axesPaths[2].stroke()

        NSColor.red.set()
        axesPaths[0].stroke()

        NSColor.green.set()
        axesPaths[1].stroke()

        NSColor.lightGray.set()
        let border = NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5)
        border.lineWidth = 3
        border.stroke()
        spherePath.value?.stroke()

        NSColor.orange.set()
        ballPath(at: bPoint.value, radius: 5).fill()

        let tether = NSBezierPath()
        tether.move(to: bPoint.value)
        tether.line(to: kitePoint.value)
        tether.lineWidth = 2
        tether.stroke()

        NSColor.purple.set()
        ballPath(at: targetPoint.value, radius: 5).fill()

        NSColor.red.set()
        ballPath(at: cPoint.value, radius: 5).fill()
        circlePath.value?.stroke()

        NSColor.black.set()
        ballPath(at: kitePoint.value, radius: 3).fill()
        kitePath.value?.stroke()

        NSColor.green.set()
        // ballPath(at: leftWingPoint, radius: 3).fill()

        NSColor.red.set()
        // ballPath(at: rightWingPoint, radius: 3).fill()
    }

    private func makePath(lines: [Line]) -> NSBezierPath {
        let p = NSBezierPath()
        p.lineWidth = 2

        for line in lines {
            p.move(to: pointify(line.start))
            p.line(to: pointify(line.end))
        }
        return p
    }

    private func makePath(line: Line) -> NSBezierPath {
        return makePath(lines: [line])
    }

    // Semi-pure functions

    private func vectorify(_ point: NSPoint) -> Vector {
        let relative = relativiser(point)
        let fullScale = upScaler(relative)
        return deProjector(fullScale)
    }

    private func pointify(_ v: Vector) -> NSPoint {
        let projected = projector(v)
        let scaledDown = downScaler(projected)
        return absolutiser(scaledDown)
    }

    private func kiteLines(position: Vector, orientation: Quaternion) -> [Line] {
        return kite.lines.map(orientation.apply).map(Line.translator(by: position))
    }

    private func circleLines(in plane: Plane, radius: Scalar) -> [Line] {
        let points = 30

        let vectors = (0...points).map { 2*π*Scalar($0)/Scalar(points) }.map { phi -> Vector in
            plane.center + radius*(sin(phi)*plane.bases.0 + cos(phi)*plane.bases.1)
        }

        return zip(vectors.dropLast(), vectors.dropFirst()).map(Line.init) //.flatMap(occlude(using: occlusionPlane))
    }

    private func occluded(lines: [Line], plane: Plane) -> [Line] {
        return lines.flatMap(occlude(using: plane))
    }

    // Pure functions

    private func sphereLines(s: Sphere) -> [Line] {
        let longitudes = 20
        let latitudes = 10

        let longDelta = 2*π/Scalar(longitudes)
        let latDelta = (π/2)/Scalar(latitudes)

        var lines = [Line]()
        for i in 0...longitudes {
            let phi = -π/2 + Scalar(i)*longDelta

            for j in 0..<latitudes {
                let theta = π/2 + Scalar(j)*latDelta
                let start = Vector(phi: phi, theta: theta, r: s.radius)
                let end = Vector(phi: phi, theta: theta + latDelta, r: s.radius)
                lines.append(Line(start: start, end: end) + s.center)
            }
        }

        for j in 0..<latitudes {
            let theta = π/2 + Scalar(j)*latDelta
            for i in 0...longitudes {
                let phi = -π/2 + Scalar(i)*longDelta
                let start = Vector(phi: phi, theta: theta, r: s.radius)
                let end = Vector(phi: phi + longDelta, theta: theta, r: s.radius)
                lines.append(Line(start: start, end: end) + s.center)
            }
        }
        
        return lines
    }

    private func occlude(using plane: Plane) -> (Line) -> Line? {
        return { line in
            let line2 = line - plane.center
            switch (line2.start•plane.normal > 0, line2.end•plane.normal > 0) {
            case (true, true): return nil
            case (false, false): return line
            case (true, false), (false, true): return line.split(by: plane).neg
            }
        }
    }

    private func ballPath(at point: NSPoint, radius r: Scalar) -> NSBezierPath {
        return NSBezierPath(ovalIn: NSRect(origin: NSPoint(x: -r, y: -r) + point, size: NSSize(width: 2*r, height: 2*r)))
    }
}

public class Tracer {
    public var projectionAxis = -e_z
    public var scaleFactor: Scalar = 70
    public var bounds: CGRect = .unit

    public func pointify(_ vector: Vector) -> CGPoint {
        return vector
            .collapsed(along: projectionAxis)
            .scaled(by: 1/scaleFactor)
            .absolute(in: bounds)
    }

    public func vectorify(_ point: CGPoint) -> Vector {
        return point
            .relative(in: bounds)
            .scaled(by: scaleFactor)
            .deCollapsed(along: projectionAxis)
    }
}

class SphereView: NSView {
    public let sphere = Variable<Sphere>(.unit)
    public let axis = Variable<Vector>(e_z)
}

struct LineArtKite {
    let span: Scalar
    let length: Scalar
    let height: Scalar

    private let tailProportion: Scalar = 0.8
    private let stabiliserProportion: Scalar = 0.8
    private let stabiliserSize: Scalar = 0.4
    private let rudderSize: Scalar = 0.3

    private let sideWingPlacement: Scalar = 0.5

    var wingstips: [Vector] {
        return [-e_y, e_y].map { span/2*$0 }
    }

    var lines: [Line] {
        let halfSpan = span/2
        let wing = halfSpan*Line(start: -e_y, end: e_y)

        let verticalWing = 1/2*Line(start: -e_x, end: e_x)
        let basicSideWing = height*verticalWing
        let rightSideWing = basicSideWing + sideWingPlacement*halfSpan*e_y
        let leftSideWing = basicSideWing - sideWingPlacement*halfSpan*e_y

        let nose = -(1 - tailProportion)*length*e_z
        let tail = nose + length*e_z
        let body = Line(start: nose, end: tail)

        let stabiliser = stabiliserSize*wing + stabiliserProportion*tail

        let rudder = rudderSize*span*verticalWing + tail - 0.4*rudderSize*span*e_x

        return [wing, rightSideWing, leftSideWing, body, stabiliser, rudder]
    }

    func scaled(s: Scalar) -> LineArtKite {
        return LineArtKite(span: s*span, length: s*length, height: s*height)
    }
}

extension AffineTransform {
    init(translationBy point: NSPoint) {
        self = AffineTransform(translationByX: point.x, byY: point.y)
    }
}

extension NSPoint {
    init(phi: Scalar, r: Scalar) {
        self = r*NSPoint(x: cos(phi), y: sin(phi))
    }

    static func *(left: Scalar, right: NSPoint) -> NSPoint {
        return NSPoint(x: left*right.x, y: left*right.y)
    }

    static func •(left: NSPoint, right: NSPoint) -> Scalar {
        return  left.x*right.x + left.y*right.y
    }

    static func +(left: NSPoint, right: NSPoint) -> NSPoint {
        return NSPoint(x: left.x + right.x, y: left.y + right.y)
    }

    static func -(left: NSPoint, right: NSPoint) -> NSPoint {
        return NSPoint(x: left.x - right.x, y: left.y - right.y)
    }

    static prefix func -(point: NSPoint) -> NSPoint {
        return NSPoint(x: -point.x, y: -point.y)
    }

    public var norm: Scalar {
        return sqrt(x*x + y*y)
    }

    public var phi: Scalar {
        return atan2(y, x)
    }

    public var r: Scalar {
        return norm
    }

    public var normSquared: Scalar {
        return x*x + y*y
    }

    public var unit: NSPoint {
        return (1/norm)*self
    }

    public func angle(to point: NSPoint) -> Scalar {
        return acos(unit•point.unit)
    }

    public func signedAngle(to point: NSPoint) -> Scalar {
        let p = point.unit
        let q = unit

        let signed = asin(p.y*q.x - p.x*q.y)

        if angle(to: point) > π/2 {
            if signed > 0 {
                return π - signed
            }
            else {
                return -π - signed
            }
        }
        else {
            return signed
        }
    }

    public func rotated(by angle: Scalar) -> NSPoint {
        return self.applying(CGAffineTransform(rotationAngle: angle))
    }

    public func deProjected(on plane: (x: Vector, y: Vector)) -> Vector {
        return x*plane.x + y*plane.y
    }

    public func scaled(_ factor: Scalar) -> NSPoint {
        return NSPoint(x: factor*x, y: factor*y)
    }

    public func absolute(in rect: NSRect) -> NSPoint {
        return NSPoint(x: rect.minX + rect.width*(0.5 + x), y: rect.minY + rect.height*(0.5 + y))
    }

    public func relative(in rect: NSRect) -> NSPoint {
        return NSPoint(x: (x - rect.minX)/rect.width - 0.5, y: (y - rect.minY)/rect.height - 0.5)
    }

    // MARK: - Higher order functions

    public static func projector(along vector: Vector) -> (Vector) -> NSPoint {
        if vector || e_z {
            return { NSPoint(x: $0.y, y: $0.x) }
        }

        let bases = Plane(center: .origin, normal: vector).bases

        return { $0.projected(on: bases) }
    }

    public static func deProjector(along vector: Vector) -> (NSPoint) -> Vector {
        if vector || e_z {
            return { Vector($0.y, $0.x, 0) }
        }

        let bases = Plane(center: .origin, normal: vector).bases

        return { $0.deProjected(on: bases) }
    }

    public static func scaler(by factor: Scalar) -> (NSPoint) -> NSPoint {
        return { $0.scaled(factor) }
    }

    public static func absolutiser(in rect: NSRect) -> (NSPoint) -> NSPoint {
        return { $0.absolute(in: rect) }
    }

    public static func relativiser(in rect: NSRect) -> (NSPoint) -> NSPoint {
        return { $0.relative(in: rect) }
    }
}

extension NSRect {
    init(center: NSPoint, size: NSSize) {
        self = NSRect(origin: center - NSPoint(x: size.width/2, y: size.height/2), size: size)
    }

    public static var unit: NSRect {
        return NSRect(x: 0, y: 0, width: 1, height: 1)
    }
}
