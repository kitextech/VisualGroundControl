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

    // MAR: - Private

    private let bag = DisposeBag()

    // MAR: - View Controller Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        let s: Scalar = 1/100

//        location.asObservable().map(NSPoint.collapsingX).map(NSPoint.scaled(s)).bindNext(yzView.add).disposed(by: bag)
//        location.asObservable().map(NSPoint.collapsingY).map(NSPoint.scaled(s)).bindNext(zxView.add).disposed(by: bag)
//        location.asObservable().map(NSPoint.collapsingZ).map(NSPoint.scaled(s)).bindNext(xyView.add).disposed(by: bag)

    }
}

public enum Axis {
    case x
    case y
    case z
}

class TraceView: NSView {

    // MARK: - Inputs
    public let location = Variable<Vector>(.origin)
    public let quaternion = Variable<Quaternion>(.id)

    // MARK: - Parameters
    public var viewDirection: Axis = .x { didSet { projector = NSPoint.collapsing(viewDirection) } }
    public var scale: Scalar = 1/100 { didSet { pointScaler = NSPoint.scaling(scale) } }

    // MARK: - Private
    private var points = [NSPoint]()

    private var path = NSBezierPath()
    private var borderPath = NSBezierPath()
    private var crossPath = NSBezierPath()

    private var projector: (Vector) -> NSPoint = NSPoint.collapsing(.x)
    private var pointScaler: (NSPoint) -> NSPoint = NSPoint.scaling(1/100)

    private let bag = DisposeBag()

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        borderPath.appendRoundedRect(bounds.insetBy(dx: 2, dy: 2), xRadius: 10, yRadius: 10)
        borderPath.lineWidth = 3

        crossPath.move(to: NSPoint(x: 0.3, y: 0))
        crossPath.line(to: NSPoint(x: 0.7, y: 0))
        crossPath.move(to: NSPoint(x: 0, y: 0.3))
        crossPath.line(to: NSPoint(x: 0, y: 0.7))
        crossPath.lineWidth = 3

        path.lineWidth = 3

        // Drawing

        Observable.zip(location.asObservable(), quaternion.asObservable(), resultSelector: noOp).bindNext(add).disposed(by: bag)
    }

    private func scale(p: NSPoint) -> NSPoint {
        return NSPoint.scaling(1/scale)(p)
    }

    private func add(v: Vector, q: Quaternion) {
        let point = projector(v)

        let scaledPoint = scaler(rect: bounds)(point)
        if points.isEmpty {
            path.move(to: scaledPoint)
        }
        else {
            path.line(to: scaledPoint)
        }

        points.append(point)

        setNeedsDisplay(bounds)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.set()
        path.stroke()

        NSColor.darkGray.set()
        borderPath.stroke()
        crossPath.stroke()
    }
}

private func scaler(rect: NSRect) -> (NSPoint) -> NSPoint {
    return { point in
        NSPoint(x: rect.minX + rect.width*point.x, y: rect.minY + rect.height*point.y)
    }
}

extension NSPoint {
    public static func collapsing(_ axis: Axis) -> (Vector) -> NSPoint {
        switch axis {
        case .x: return { v in NSPoint(x: v.y, y: v.z) }
        case .y: return { v in NSPoint(x: v.z, y: v.x) }
        case .z: return { v in NSPoint(x: v.x, y: v.y) }
        }
    }

    public static func scaling(_ factor: Scalar) -> (NSPoint) -> NSPoint {
        return { p in
            NSPoint(x: factor*p.x, y: factor*p.y)
        }
    }
}
