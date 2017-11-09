//
//  Pursuit.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-04-08.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import RxSwift
import QuartzCore

class PursuitViewController: NSViewController {
    @IBOutlet weak var slidar0: NSSlider!
    @IBOutlet weak var slider1: NSSlider!
    @IBOutlet weak var slider2: NSSlider!
    @IBOutlet weak var slider3: NSSlider!

    @IBOutlet weak var pursuitView: PursuitView!

    private let bag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        slidar0.scalar.bind { self.pursuitView.speed = $0 }.disposed(by: bag)
        slider1.scalar.bind { self.pursuitView.pathRadius = $0 }.disposed(by: bag)
        slider2.scalar.bind { self.pursuitView.searchRadius = $0 }.disposed(by: bag)
    }
}

class PursuitView: NSView {
    // Parameters
    public var speed: Scalar = 5 { didSet { pursuit.speed = speed } }
    public var pathRadius: Scalar = 300 { didSet { pursuit.pathRadius = pathRadius } }
    public var searchRadius: Scalar = 200 { didSet { pursuit.searchRadius = searchRadius } }

    // Internal

    private var position = CGPoint.zero
    private var yaw: Scalar = -π/4

    private var velocity: CGPoint { return CGPoint(phi: -yaw, r: speed) }

    private var target: CGPoint = .zero

    private var arcCenter: CGPoint = .zero
    private var arcRadius: Scalar = 1000000
    private var arcAngle: Scalar = 0
    private var yawRate: Scalar = 0

    private var trail = [CGPoint]()

    private var timer: Timer!
    private var isPaused = false

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        acceptsTouchEvents = true

        pursuit.speed = speed
        pursuit.searchRadius = searchRadius
        pursuit.pathRadius = pathRadius

        timer = Timer(timeInterval: 0.05, repeats: true, block: { _ in self.update() } )

        RunLoop.current.add(timer, forMode:.defaultRunLoopMode)
        RunLoop.current.add(timer, forMode:.eventTrackingRunLoopMode)
    }

    override func mouseDown(with event: NSEvent) {
        isPaused = true
        processMouseEvent(event)
    }

    override func mouseDragged(with event: NSEvent) {
        processMouseEvent(event)
    }

    override func mouseUp(with event: NSEvent) {
        isPaused = false
    }

    override func scrollWheel(with event: NSEvent) {
        position.x += event.deltaX/3
        position.y -= event.deltaY/3

        setNeedsDisplay(bounds)
    }

    private func processMouseEvent(_ event: NSEvent) {
        position = convert(event.locationInWindow, from: nil)
        trail = []
        setNeedsDisplay(bounds)
    }

    private var pursuit = Pursuit(n: 60)

    func update() {
        (target, arcAngle, arcCenter, arcRadius, yawRate) = pursuit.update(position: position, velocity: velocity)

        guard !isPaused else {
            return
        }

        yaw = (yaw + yawRate + 2*π).truncatingRemainder(dividingBy: 2*π)
        position = position + velocity

        trail.append(position)
        setNeedsDisplay(bounds)
    }

    override func draw(_ dirtyRect: CGRect) {
        // Draw search area
        NSColor(calibratedRed: 0.8, green: 0.8, blue: 0.8, alpha: 1).set()
        ballPath(at: position, radius: searchRadius).fill()

        // Draw kite path
        NSColor.lightGray.set()
        ballPath(at: pursuit.center, radius: pathRadius).stroke()

        // Draw target
        NSColor.blue.set()
        ballPath(at: target, radius: 5).stroke()

        // Draw trail
        NSColor.gray.set()
        makePath(points: trail)?.stroke()

        // Draw position
        NSColor.orange.set()
        ballPath(at: position, radius: 5).fill()

        makePath(lines: [(position, position + 10*velocity)]).stroke()

        // Draw arc
        NSColor.purple.set()
        let arc = NSBezierPath()
        let startAngle = 180*(position - arcCenter).phi/π
        let endAngle = 180*(target - arcCenter).phi/π

        let clockWise = (target - position).signedAngle(to: CGPoint(phi: -yaw, r: 1)) > 0
        arc.appendArc(withCenter: arcCenter, radius: abs(arcRadius), startAngle: startAngle, endAngle: endAngle, clockwise: clockWise)
        arc.lineWidth = 2
        arc.stroke()

        ballPath(at: arcCenter, radius: 5).fill()

        let attrib: [NSAttributedStringKey: AnyObject] = [
            .foregroundColor : NSColor.black,
            .font : NSFont.systemFont(ofSize: 17)
        ]

        ("yaw: \(180*yaw/π)" as NSString).draw(in: CGRect(x: 200, y: 310, width: 300, height: 35), withAttributes: attrib)

        ("arcAngle: \(180*arcAngle/π)" as NSString).draw(in: CGRect(x: 200, y: 350, width: 300, height: 35), withAttributes: attrib)

        ("yawRate: \(180*yawRate/π)" as NSString).draw(in: CGRect(x: 200, y: 390, width: 300, height: 35), withAttributes: attrib)

        ("pos: \(Int(position.x)):\(Int(position.y))" as NSString).draw(in: CGRect(x: 200, y: 430, width: 300, height: 35), withAttributes: attrib)

        ("arcRadius: \(arcRadius)" as NSString).draw(in: CGRect(x: 200, y: 470, width: 300, height: 35), withAttributes: attrib)

        ("trail: \(trail.count)" as NSString).draw(in: CGRect(x: 200, y: 510, width: 300, height: 35), withAttributes: attrib)

        //        makePath(lines: [(position, position + 10*)]) // draw yawrate
    }

    private func ballPath(at point: CGPoint, radius r: Scalar) -> NSBezierPath {
        return NSBezierPath(ovalIn: CGRect(origin: CGPoint(x: -r, y: -r) + point, size: NSSize(width: 2*r, height: 2*r)))
    }

    private func makePath(lines: [(start: CGPoint, end: CGPoint)]) -> NSBezierPath {
        let p = NSBezierPath()
        p.lineWidth = 2

        for line in lines {
            p.move(to: line.start)
            p.line(to: line.end)
        }
        return p
    }

    private func makePath(points: [CGPoint]) -> NSBezierPath? {
        guard let first = points.first else { return nil }
        
        let p = NSBezierPath()
        p.lineWidth = 2
        
        p.move(to: first)
        
        for point in points.dropFirst() {
            p.line(to: point)
        }
        
        return p
    }
}

struct Pursuit {
    // Parameters
    public var center: CGPoint = CGPoint(x: 700, y: 400)
    
    public var speed: Scalar = 5
    public var pathRadius: Scalar = 300
    public var searchRadius: Scalar = 200

    // Internal

    private let n: Int
    private let basePathPoints: [CGPoint]

    private var index = 0
    private var target: CGPoint { return pathPoint(index) }

    init(n: Int) {
        self.n = n
        self.basePathPoints = (0..<n).map { Scalar($0)*2*π/Scalar(n) }.map { CGPoint(x: sin($0), y: cos($0)) }
    }

    func pathPoint(_ i: Int) -> CGPoint {
        return center + pathRadius*basePathPoints[i]
    }

    mutating func update(position: CGPoint, velocity: CGPoint) -> (target: CGPoint, arcAngle: Scalar, arcCenter: CGPoint, arcRadius: Scalar, yawRate: Scalar) {
        while (pathPoint(index) - position).norm < searchRadius {
            index = (index + 1) % n
        }

        let attitude = velocity.unit
        let (arcAngle, arcCenter, arcRadius) = Pursuit.angleCenterRadius(position: position, target: target, attitude: attitude)
        let yawRate = -speed/arcRadius

        return (target, arcAngle, arcCenter, arcRadius, yawRate)
    }

    static public func angleCenterRadius(position: CGPoint, target: CGPoint, attitude: CGPoint) -> (arcAngle: Scalar, center: CGPoint, radius: Scalar) {
        let arcAngle = attitude.signedAngle(to: target - position)
        let arcRadius = (arcAngle.sign == .plus ? 1 : -1)*(target - position).norm/sqrt(2*(1 - cos(2*arcAngle)))
        let arcCenter = position + arcRadius*attitude.rotated(by: π/2)

        return (arcAngle, arcCenter, arcRadius)
    }
}

