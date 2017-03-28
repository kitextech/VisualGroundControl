//
//  TraceViewsViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-18.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import RxSwift

class TraceViewsViewController: NSViewController {
    // MAR: - Outlets

    @IBOutlet weak var xyView: TraceView!
    @IBOutlet weak var yzView: TraceView!
    @IBOutlet weak var zxView: TraceView!

    @IBOutlet weak var alphaSlider: NSSlider!

    // MAR: - Private

    private let kite = KiteLink.shared
    private let bag = DisposeBag()

    // MAR: - View Controller Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        let scale: Scalar = 1/100
        xyView.scale = scale
        yzView.scale = scale
        zxView.scale = scale

        xyView.viewDirection = .z
        yzView.viewDirection = .x
        zxView.viewDirection = .y

        let position = Variable<Vector>(.zero)
        kite.location.map(KiteLocation.getPosition).bindTo(position).disposed(by: bag)

        position.asObservable().bindTo(xyView.position).disposed(by: bag)
        position.asObservable().bindTo(yzView.position).disposed(by: bag)
        position.asObservable().bindTo(zxView.position).disposed(by: bag)

        let quaternion = Variable<Quaternion>(.id)
        print("Binding kite quaternion to traces")

        kite.quaternion.map(KiteQuaternion.getQuaternion).bindTo(quaternion).disposed(by: bag)

//        alphaSlider.scalar.map { Quaternion(rotationAround: self.axis, by: $0) }.bindTo(quaternion).disposed(by: bag)

        quaternion.asObservable().bindTo(xyView.quaternion).disposed(by: bag)
        quaternion.asObservable().bindTo(yzView.quaternion).disposed(by: bag)
        quaternion.asObservable().bindTo(zxView.quaternion).disposed(by: bag)

        kite.positionB.asObservable().bindTo(xyView.positionB).disposed(by: bag)
        kite.positionB.asObservable().bindTo(yzView.positionB).disposed(by: bag)
        kite.positionB.asObservable().bindTo(zxView.positionB).disposed(by: bag)

        kite.positionTarget.asObservable().bindTo(xyView.positionTarget).disposed(by: bag)
        kite.positionTarget.asObservable().bindTo(yzView.positionTarget).disposed(by: bag)
        kite.positionTarget.asObservable().bindTo(zxView.positionTarget).disposed(by: bag)

        kite.tetherLength.asObservable().bindTo(xyView.tetherLength).disposed(by: bag)
        kite.tetherLength.asObservable().bindTo(yzView.tetherLength).disposed(by: bag)
        kite.tetherLength.asObservable().bindTo(zxView.tetherLength).disposed(by: bag)
    }

    var axis = e_x

    @IBAction func didSelectAxis(_ sender: NSButton) {
        axis = [e_x, e_y, e_z][sender.tag]
    }
}

public enum Axis {
    case x
    case y
    case z
}

class TraceView: NSView {
    // MARK: - Inputs
    public let position = Variable<Vector>(.origin)
    public let quaternion = Variable<Quaternion>(.id)
    public let positionB = Variable<Vector>(.origin)
    public let positionTarget = Variable<Vector>(.origin)

    public let tetherLength = Variable<Scalar>(50)

    // MARK: - Parameters
    public var viewDirection: Axis = .z { didSet { projector = NSPoint.collapser(viewDirection) } }
    public var scale: Scalar = 1/70 { didSet { downScaler = NSPoint.scaler(scale) } }

    // MARK: - Outputs

    // MARK: - Private
    private var path = NSBezierPath()

    private var kitePaths = [NSBezierPath]()

    private var spherePaths = [NSBezierPath]()

    private var projector = NSPoint.collapser(.x)
    private var downScaler = NSPoint.scaler(1/70)

    private var lineTranslator = Line.translator(by: .zero)

    private var kitePoint: NSPoint = .zero
    private var bPoint: NSPoint = .zero
    private var kitePointTarget: NSPoint = .zero

    private var leftWingPoint: NSPoint = .zero
    private var rightWingPoint: NSPoint = .zero

    private var hasStartedDrawing = false

    private let bag = DisposeBag()

    private let kite = LineArtKite(span: 1.2, length: 1, height: 0.6).scaled(s: 20)

    private let axes = [e_x, e_y, e_z].map { 40*Line(start: .origin, end: $0) }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        path.lineWidth = 1

        // Drawing

        Observable.combineLatest(position.asObservable(), quaternion.asObservable(), resultSelector: noOp).bindNext(add).disposed(by: bag)

        positionB.asObservable().subscribe(onNext: bChanged).disposed(by: bag)
        tetherLength.asObservable().subscribe(onNext: tetherLengthChanged).disposed(by: bag)
        positionTarget.asObservable().subscribe(onNext: targetChanged).disposed(by: bag)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let downScaled = point.deScaled(bounds)
        let upScaled = downScaled.scaled(1/scale)
        let vector = NSPoint.deCollapser(viewDirection)(upScaled)

        let bSphere = Sphere(center: positionB.value, radius: tetherLength.value)
        let projected = project(vector: vector, on: bSphere, along: viewDirection)

        KiteLink.shared.positionTarget.value = projected
    }

    private func project(vector v: Vector, on sphere: Sphere, along axis: Axis) -> Vector {
        let r = sphere.radius
        let u = v - sphere.center
        let w = u.norm > r ? r*u.unit : u

        switch axis {
        case .x: return Vector(sqrt(r*r - w.y*w.y - w.z*w.z), w.y, w.z) + sphere.center
        case .y: return Vector(w.x, sqrt(r*r - w.z*w.z - w.x*w.x), w.z) + sphere.center
        case .z: return Vector(w.x, w.y, -sqrt(r*r - w.x*w.x - w.y*w.y)) + sphere.center
        }
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()

        setNeedsDisplay(bounds)
//        upScaler = NSPoint.scaler(bounds)
    }

    private func drawablePoint(_ v: Vector) -> NSPoint {
        let projected = projector(v)
        let scaledDown = downScaler(projected)
        let scaledUp = NSPoint.scaler(bounds)(scaledDown)

        return scaledUp
    }

    // Changes

    private func targetChanged(t: Vector) {
        kitePointTarget = drawablePoint(t)
        setNeedsDisplay(bounds)
    }

    private func tetherLengthChanged(r: Scalar) {
        spherePaths = sphereLines(s: Sphere(center: positionB.value, radius: r)).map(makePath)
        setNeedsDisplay(bounds)
    }

    private func bChanged(b: Vector) {
        bPoint = drawablePoint(b)
        spherePaths = sphereLines(s: Sphere(center: b, radius: tetherLength.value)).map(makePath)
        setNeedsDisplay(bounds)
    }

    private func add(p: Vector, q: Quaternion) {
        lineTranslator = Line.translator(by: p)

        kitePoint = drawablePoint(p)

        leftWingPoint = drawablePoint(q.apply(kite.wingstips[0] + p))
        rightWingPoint = drawablePoint(q.apply(kite.wingstips[1] + p))

//        if hasStartedDrawing {
//            path.line(to: kitePoint)
//        }
//        else {
//            path.move(to: kitePoint)
//            hasStartedDrawing = true
//        }

        kitePaths = kite.lines.map(q.apply).map(lineTranslator).map(makePath)

        setNeedsDisplay(bounds)
    }

    private func makePath(line: Line) -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: drawablePoint(line.start))
        p.line(to: drawablePoint(line.end))
        p.lineWidth = 2
        return p
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
        spherePaths.forEach { $0.stroke() }

        let crossPath = NSBezierPath()
        crossPath.move(to: NSPoint(x: -0.3, y: 0).scaled(bounds))
        crossPath.line(to: NSPoint(x: 0.3, y: 0).scaled(bounds))
        crossPath.move(to: NSPoint(x: 0, y: -0.3).scaled(bounds))
        crossPath.line(to: NSPoint(x: 0, y: 0.3).scaled(bounds))
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
        ballPath(at: leftWingPoint, radius: 3).fill()

        NSColor.red.set()
        ballPath(at: rightWingPoint, radius: 3).fill()
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

    public static func collapser(_ axis: Axis) -> (Vector) -> NSPoint {
        switch axis {
        case .x: return { v in NSPoint(x: v.y, y: -v.z) }
        case .y: return { v in NSPoint(x: v.x, y: -v.z) }
        case .z: return { v in NSPoint(x: v.x, y: v.y) }
        }
    }

    public static func deCollapser(_ axis: Axis) -> (NSPoint) -> Vector {
        switch axis {
        case .x: return { p in Vector(0, p.x, -p.y) }
        case .y: return { p in Vector(p.x, 0, -p.y) }
        case .z: return { p in Vector(p.x, p.y, 0) }
        }
    }

    public static func scaler(_ factor: Scalar) -> (NSPoint) -> NSPoint {
        return { $0.scaled(factor) }
    }

    public func scaled(_ factor: Scalar) -> NSPoint {
        return NSPoint(x: factor*x, y: factor*y)
    }

    public static func scaler(_ rect: NSRect) -> (NSPoint) -> NSPoint {
        return { $0.scaled(rect) }
    }

    public func scaled(_ rect: NSRect) -> NSPoint {
        return NSPoint(x: rect.minX + rect.width*(0.5 + x), y: rect.minY + rect.height*(0.5 + y))
    }

    public static func deScaler(_ rect: NSRect) -> (NSPoint) -> NSPoint {
        return { $0.deScaled(rect) }
    }

    public func deScaled(_ rect: NSRect) -> NSPoint {
        return NSPoint(x: (x - rect.minX)/rect.width - 0.5, y: (y - rect.minY)/rect.height - 0.5)
    }
}
