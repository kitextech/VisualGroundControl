//
//  TraceView.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-06-30.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import RxSwift
import QuartzCore

class TraceView: NSView {
    // MARK: - Parameters

    public var phi: Scalar = 0
    public var theta: Scalar = 0

    public var scrolls = false

    public var domeRadius: Scalar = 10 { didSet { domeDrawable.radius = domeRadius } }

    // MARK: - Private

    private var dome: Sphere { return Sphere(center: .origin, radius: self.domeRadius) }
    private let domeDrawable = SphereDrawable()

    private var tracer = Tracer()
    private var drawables = [UUID : Drawable]()

    // MARK: - Inputs

    // MARK: - Output

    public var requestedPositions: [Variable<Vector>] = []

    // Initialiser

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        acceptsTouchEvents = true
        add(domeDrawable)
    }

    // Public Methods

    public func redraw() {
        setNeedsDisplay(bounds)
    }

    public func add(_ drawable: Drawable) {
        drawables[drawable.id] = drawable
        redraw()
    }

    public func rotate(_ dPhi: Scalar, _ dTheta: Scalar) {
        phi += dPhi
        theta += dTheta
        tracer.projectionAxis = Vector(phi: phi, theta: theta, r: 1)
    }

    private func boundsChanged(rect: CGRect) {
        tracer.bounds = rect
        redraw()
    }

    // Actions

    private var requestedPositionCurrent: Variable<Vector>?

    private func touchPoint(event: NSEvent) -> CGPoint {
        return convert(event.locationInWindow, from: nil)
    }

    private func domeVector(point: CGPoint) -> Vector {
        return dome.spherify(vector: tracer.vectorify(point), along: tracer.projectionAxis)
    }

    override func mouseDown(with event: NSEvent) {
        func dist(_ v: Variable<Vector>) -> Scalar {
            return (tracer.pointify(v.value) - touchPoint(event: event)).norm
        }

        func grabbable(_ v: Variable<Vector>) -> Bool {
            return dist(v) < 10 && (tracer.projectionAxis == -e_z ? v.value.z <= 0 : v.value•tracer.projectionAxis <= 0.01)
        }

        requestedPositionCurrent = requestedPositions.sorted { dist($0) < dist($1) }.first(where: grabbable)
        redraw()
    }

    override func mouseDragged(with event: NSEvent) {
        requestedPositionCurrent?.value = domeVector(point: touchPoint(event: event))
        redraw()
    }

    override func mouseUp(with event: NSEvent) {
        requestedPositionCurrent = nil
    }

    override func mouseExited(with event: NSEvent) {
        requestedPositionCurrent = nil
    }

    override func scrollWheel(with event: NSEvent) {
        guard scrolls else { return }

        rotate(-event.deltaX/20, event.deltaY/20)
        redraw()
    }

    override func magnify(with event: NSEvent) {
        tracer.scaleFactor /= 1 + 0.6*event.magnification
        redraw()
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        boundsChanged(rect: bounds)
    }

    // Drawing

    override func draw(_ dirtyRect: CGRect) {
        drawables.values.filter { !$0.isHidden }.forEach(draw)
    }

    // Drawing Helper Methods

    private func draw(_ drawable: Drawable) {
        drawable.color.set()

        let lines = drawable.lines
            .map { $0.rotated(drawable.orientation) }
            .map { $0.translated(drawable.position) }

        let occlusionPlane = Plane(center: .origin, normal: tracer.projectionAxis)

        linesPath(lines: drawable.occlude ? lines.flatMap(occlusionPlane.occlude) : lines, width: drawable.lineWidth).stroke()

        drawable.spheres
            .map { $0.translated(drawable.position) }
            .map(spherePath)
            .forEach { $0.fill() }
    }

    private func linesPath(lines: [Line], width: Scalar) -> NSBezierPath {
        let p = NSBezierPath()
        p.lineWidth = width

        for line in lines {
            p.move(to: tracer.pointify(line.start))
            p.line(to: tracer.pointify(line.end))
        }
        return p
    }

    private func spherePath(sphere: Sphere) -> NSBezierPath {
        let rect = CGRect(center: tracer.pointify(sphere.center), size: tracer.project(CGSize(side: sphere.radius)))
        return NSBezierPath(ovalIn: rect)
    }
}
