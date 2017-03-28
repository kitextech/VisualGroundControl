//
//  TraceViewsViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-18.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import RxSwift

func map<S, T>(f: @escaping (S) -> T) -> ([S]) -> [T] {
    return { $0.map(f) }
}

class TraceViewsViewController: NSViewController {
    // MARK: - Parameters

    // MARK: - Outlets

    @IBOutlet weak var xyView: TraceView!
    @IBOutlet weak var freeView: TraceView!

    // MARK: - Private

    private let kite = KiteLink.shared
    private let bag = DisposeBag()

    // MARK: - View Controller Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        let scale: Scalar = 1/100
        xyView.scale.value = scale
        freeView.scale.value = scale

        xyView.viewDirection.value = e_z
        freeView.viewDirection.value = e_x

        let position = Variable<Vector>(.zero)
        kite.location.map(KiteLocation.getPosition).bindTo(position).disposed(by: bag)

        position.asObservable().bindTo(xyView.position).disposed(by: bag)
        position.asObservable().bindTo(freeView.position).disposed(by: bag)

        let quaternion = Variable<Quaternion>(.id)
        print("Binding kite quaternion to traces")

        kite.quaternion.map(KiteQuaternion.getQuaternion).bindTo(quaternion).disposed(by: bag)

        quaternion.asObservable().bindTo(xyView.quaternion).disposed(by: bag)
        quaternion.asObservable().bindTo(freeView.quaternion).disposed(by: bag)

        kite.positionB.asObservable().bindTo(xyView.positionB).disposed(by: bag)
        kite.positionB.asObservable().bindTo(freeView.positionB).disposed(by: bag)

        kite.positionTarget.asObservable().bindTo(xyView.positionTarget).disposed(by: bag)
        kite.positionTarget.asObservable().bindTo(freeView.positionTarget).disposed(by: bag)

        kite.tetherLength.asObservable().bindTo(xyView.tetherLength).disposed(by: bag)
        kite.tetherLength.asObservable().bindTo(freeView.tetherLength).disposed(by: bag)
    }
}

class TraceView: NSView {
    // MARK: - Inputs
    public let kiteOrientation = Variable<Quaternion>(.id)

    public let kitePosition = Variable<Vector>(.origin)
    public let bPosition = Variable<Vector>(.origin)
    public let targetPosition = Variable<Vector>(.origin)

    public let tetherLength = Variable<Scalar>(50)

    // MARK: - Parameters

    public let axis = Variable<Vector>(e_z)
    public let scale = Variable<Scalar>(70)

    // MARK: - Private

    private let kitePoint = Variable<NSPoint>(.zero)
    private let bPoint = Variable<NSPoint>(.zero)
    private let targetPoint = Variable<NSPoint>(.zero)

    private let sphere = Variable<Sphere>(.unit)



    // MARK: - Visual

    private var spherePath = Variable<NSBezierPath?>(nil)
    private var kitePath = Variable<NSBezierPath?>(nil)

    // Actors

    private var projector = NSPoint.projector(along: e_z)
    private var deProjector = NSPoint.deProjector(along: e_z)

    private var upScaler = NSPoint.scaler(by: 70)
    private var downScaler = NSPoint.scaler(by: 1/70)

    private var absolutiser = NSPoint.absolutiser(in: .unit)
    private var relativiser = NSPoint.relativiser(in: .unit)

    private var spherifier: (Vector) -> Vector = noOp

    // Properties

    private var path = NSBezierPath()



    // Constants

    private let bag = DisposeBag()
    private let kite = LineArtKite(span: 1.2, length: 1, height: 0.6).scaled(s: 20)
    private let axes = [e_x, e_y, e_z].map { 40*Line(start: .origin, end: $0) }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        path.lineWidth = 1

        // Drawing

        kitePosition.asObservable().map(pointify).bindTo(kitePoint).disposed(by: bag)
        bPosition.asObservable().map(pointify).bindTo(bPoint).disposed(by: bag)
        targetPosition.asObservable().map(pointify).bindTo(targetPoint).disposed(by: bag)


        Observable.combineLatest(kitePosition.asObservable(), kiteOrientation.asObservable(), resultSelector: noOp).bindNext(add).disposed(by: bag)



        positionTarget.asObservable().subscribe(onNext: targetChanged).disposed(by: bag)

        viewDirection.asObservable().subscribe(onNext: viewDirectionChanged).disposed(by: bag)

        Observable.combineLatest(positionB.asObservable(), tetherLength.asObservable(), resultSelector: Sphere.init).bindTo(sphere).disposed(by: bag)

        Observable.combineLatest(sphere.asObservable(), viewDirection.asObservable(), resultSelector: noOp).bindNext(sphereOrViewDirectionChanged).disposed(by: bag)

        sphere.asObservable().map(sphereLines).map(makePath).bindTo(spherePath).disposed(by: bag)




        // visible
    }

    private func viewDirectionChanged(vector: Vector) {
        projector = NSPoint.projector(along: vector)
        deProjector = NSPoint.deProjector(along: vector)
    }

    private func sphereOrViewDirectionChanged(sphere: Sphere, normal: Vector) {
        spherifier = Sphere.spherifier(along: normal, on: sphere)
    }

    private func orientationChanged(vector: Vector) {
        // FIXME: rotate kite
    }

    private func scaleChanged(scale: Scalar) {
        downScaler = NSPoint.scaler(by: 1/scale)
        upScaler = NSPoint.scaler(by: scale)
    }

    private func boundsChanged(rect: NSRect) { // FIXME: Call this
        absolutiser = NSPoint.absolutiser(in: rect)
        relativiser = NSPoint.relativiser(in: rect)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let vector = vectorify(point)
        KiteLink.shared.positionTarget.value = spherifier(vector)
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()

        boundsChanged(rect: bounds)

        setNeedsDisplay(bounds)
//        upScaler = NSPoint.scaler(bounds)
    }

    // Point and vector

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

    // Changes

    private func setNeedsDisplay<T>(ignored: T) {
        setNeedsDisplay(bounds)
    }

    private func kiteLines(position: Vector, orientation: Quaternion) -> [Line] {

//        leftWingPoint = drawablePoint(q.apply(kite.wingstips[0] + p))
//        rightWingPoint = drawablePoint(q.apply(kite.wingstips[1] + p))

//        if hasStartedDrawing {
//            path.line(to: kitePoint)
//        }
//        else {
//            path.move(to: kitePoint)
//            hasStartedDrawing = true
//        }

        let lineTranslator = Line.translator(by: p)

        kitePaths = kite.lines.map(q.apply).map(lineTranslator).map(makePath)

        setNeedsDisplay(bounds)
    }

    func ballPath(at point: NSPoint, radius r: Scalar) -> NSBezierPath {
        return NSBezierPath(ovalIn: NSRect(origin: NSPoint(x: -r, y: -r) + point, size: NSSize(width: 2*r, height: 2*r)))
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.lightGray.set()
//        path.stroke()

        NSColor.lightGray.set()
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 4), xRadius: 5, yRadius: 5)
        border.lineWidth = 3
        border.stroke()
        spherePath.value.stroke()

        let crossPath = NSBezierPath()
        crossPath.move(to: absolutiser(NSPoint(x: -0.3, y: 0)))
        crossPath.line(to: absolutiser(NSPoint(x: 0.3, y: 0)))
        crossPath.move(to: absolutiser(NSPoint(x: 0, y: -0.3)))
        crossPath.line(to: absolutiser(NSPoint(x: 0, y: 0.3)))
        crossPath.lineWidth = 1
        crossPath.stroke()

        let axesPaths = axes.map(makePath)
        NSColor.red.set()
        axesPaths[0].stroke()

        NSColor.green.set()
        axesPaths[1].stroke()

        NSColor.blue.set()
        axesPaths[2].stroke()

        NSColor.orange.set()
        ballPath(at: bPoint, radius: 5).fill()

        let tether = NSBezierPath()
        tether.move(to: bPoint)
        tether.line(to: kitePoint)
        tether.lineWidth = 2
        tether.stroke()

        NSColor.purple.set()
        ballPath(at: kitePointTarget, radius: 5).fill()

        NSColor.black.set()
        kitePaths.forEach { $0.stroke() }
        ballPath(at: kitePoint, radius: 3).fill()

        NSColor.green.set()
        // ballPath(at: leftWingPoint, radius: 3).fill()

        NSColor.red.set()
        // ballPath(at: rightWingPoint, radius: 3).fill()
    }

    private func makePath(lines: [Line]) -> NSBezierPath {

    }

    private func makePath(line: Line) -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: pointify(line.start))
        p.line(to: pointify(line.end))
        p.lineWidth = 2
        return p
    }

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
}

class SphereView: NSView {
    public let sphere = Variable<Sphere>(.unit)
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
    static func +(left: NSPoint, right: NSPoint) -> NSPoint {
        return NSPoint(x: left.x + right.x, y: left.y + right.y)
    }

    static func -(left: NSPoint, right: NSPoint) -> NSPoint {
        return NSPoint(x: left.x - right.x, y: left.y - right.y)
    }

    static prefix func -(point: NSPoint) -> NSPoint {
        return NSPoint(x: -point.x, y: -point.y)
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
            return { NSPoint(x: $0.x, y: -$0.y) }
        }

        let bases = Plane(center: .origin, normal: vector).bases

        return { $0.projected(on: bases) }
    }

    public static func deProjector(along vector: Vector) -> (NSPoint) -> Vector {
        if vector || e_z {
            return { Vector($0.x, -$0.y, 0) }
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
    public static var unit: NSRect {
        return NSRect(x: 0, y: 0, width: 1, height: 1)
    }
}
