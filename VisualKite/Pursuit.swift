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

        slidar0.scalar.bindNext { self.pursuitView.speed = $0 }.disposed(by: bag)
        slider1.scalar.bindNext { self.pursuitView.pathRadius = $0 }.disposed(by: bag)
        slider2.scalar.bindNext { self.pursuitView.searchRadius = $0 }.disposed(by: bag)
    }
}

let n = 60
let c = NSPoint(x: 700, y: 400)

class PursuitView: NSView {
    // Parameters
    var speed: Scalar = 5 { didSet { setNeedsDisplay(bounds) } }
    var pathRadius: Scalar = 300 { didSet { setNeedsDisplay(bounds) } }
    var searchRadius: Scalar = 200 { didSet { setNeedsDisplay(bounds) } }

    // Internal

    var position = NSPoint.zero
    var yaw: Scalar = π/4

    let basePathPoints = (0..<n).map { Scalar($0)*2*π/Scalar(n) }.map { NSPoint(x: sin($0), y: cos($0)) }

    var pathPoints: [NSPoint] { return basePathPoints.map { c + pathRadius*$0} }

    var index = 0
    var target: NSPoint { return pathPoints[index] }

    var arcCenter = NSPoint.zero
    var arcRadius: Scalar = 1000000
    var arcAngle: Scalar = 0
    var yawRate: Scalar = 0

    var trail = [NSPoint]()

    var timer: Timer!

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        acceptsTouchEvents = true

        timer = Timer(timeInterval: 0.05, repeats: true, block: { _ in self.next() } )

        RunLoop.current.add(timer, forMode:.defaultRunLoopMode)
        RunLoop.current.add(timer, forMode:.eventTrackingRunLoopMode)
    }

    override func mouseDown(with event: NSEvent) {
        processMouseEvent(event)
    }

    override func mouseDragged(with event: NSEvent) {
        processMouseEvent(event)
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

    func radiusChanged(r: Scalar) {
        pathRadius = r
    }

    func next() {
        updateTarget()
        updateArc()
        updateYawRate()
        updatePosition()
        trail.append(position)
        setNeedsDisplay(bounds)
    }

    func updateTarget() {
        var i = index

        while (pathPoints[i] - position).norm < searchRadius {
            i = (i + 1) % n
        }
        index = i
    }

    func updateArc() {
        let attitude = NSPoint(phi: yaw, r: 1)
        arcAngle = attitude.signedAngle(to: target - position)
        arcRadius = (target - position).norm/sqrt(2*(1 - cos(2*arcAngle)))
        arcCenter = position + arcRadius*attitude.rotated(by: (arcAngle.sign == .plus ? 1 : -1)*π/2)
    }

    func updateYawRate() {
        yawRate = (arcAngle.sign == .plus ? 1 : -1)*speed/arcRadius
    }

    func updatePosition() {
        position = position + NSPoint(phi: yaw, r: speed)
        yaw = (yaw + yawRate + 2*π).truncatingRemainder(dividingBy: 2*π)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Draw search area
        NSColor(calibratedRed: 0.8, green: 0.8, blue: 0.8, alpha: 1).set()
        ballPath(at: position, radius: searchRadius).fill()

        // Draw kite path
        NSColor.lightGray.set()
        ballPath(at: c, radius: pathRadius).stroke()

        // Draw target
        NSColor.blue.set()
        ballPath(at: target, radius: 5).stroke()

        // Draw trail
        NSColor.gray.set()
        makePath(points: trail)?.stroke()

        // Draw position
        NSColor.orange.set()
        ballPath(at: position, radius: 5).fill()
        makePath(lines: [(position, position + NSPoint(phi: yaw, r: 10*speed))]).stroke()

        // Draw arc
        NSColor.purple.set()
        let arc = NSBezierPath()
        let startAngle = 180*(position - arcCenter).phi/π
        let endAngle = 180*(target - arcCenter).phi/π

        let clockWise = (target - position).signedAngle(to: NSPoint(phi: yaw, r: 1)) > 0
        arc.appendArc(withCenter: arcCenter, radius: arcRadius, startAngle: startAngle, endAngle: endAngle, clockwise: clockWise)
        arc.lineWidth = 2
        arc.stroke()

        ballPath(at: arcCenter, radius: 5).fill()

        let attrib: [String: AnyObject] = [
            NSForegroundColorAttributeName : NSColor.black,
            NSFontAttributeName : NSFont.systemFont(ofSize: 17)
        ]

        ("yaw: \(180*yaw/π)" as NSString).draw(in: NSRect(x: 10, y: 10, width: 300, height: 35), withAttributes: attrib)

        ("arcAngle: \(180*arcAngle/π)" as NSString).draw(in: NSRect(x: 10, y: 50, width: 300, height: 35), withAttributes: attrib)

        ("yawRate: \(180*yawRate/π)" as NSString).draw(in: NSRect(x: 10, y: 90, width: 300, height: 35), withAttributes: attrib)

        ("pos: \(Int(position.x)):\(Int(position.y))" as NSString).draw(in: NSRect(x: 10, y: 130, width: 300, height: 35), withAttributes: attrib)

        ("trail: \(trail.count))" as NSString).draw(in: NSRect(x: 10, y: 170, width: 300, height: 35), withAttributes: attrib)

        //        makePath(lines: [(position, position + 10*)]) // draw yawrate
    }

    private func ballPath(at point: NSPoint, radius r: Scalar) -> NSBezierPath {
        return NSBezierPath(ovalIn: NSRect(origin: NSPoint(x: -r, y: -r) + point, size: NSSize(width: 2*r, height: 2*r)))
    }

    private func makePath(lines: [(start: NSPoint, end: NSPoint)]) -> NSBezierPath {
        let p = NSBezierPath()
        p.lineWidth = 2

        for line in lines {
            p.move(to: line.start)
            p.line(to: line.end)
        }
        return p
    }

    private func makePath(points: [NSPoint]) -> NSBezierPath? {
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
