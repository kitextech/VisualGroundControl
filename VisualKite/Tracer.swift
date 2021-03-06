//
//  Tracer.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-06-30.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import Foundation

public class Tracer {
    public var offset: CGPoint = .zero
    public var projectionAxis = e_z
    public var scaleFactor: Scalar = 70
    public var bounds: CGRect = .unit

    public func project(_ vectorSize: CGSize) -> CGSize {
        return vectorSize
            .scaled(by: 1/scaleFactor)
            .absolute(in: bounds)
    }

    public func pointify(_ vector: Vector) -> CGPoint {
        return vector
            .collapsed(along: projectionAxis)
            .scaled(by: 1/scaleFactor)
            .absolute(in: bounds)
            .translated(by: offset)
    }

    public func vectorify(_ point: CGPoint) -> Vector {
        return point
            .translated(by: -offset)
            .relative(in: bounds)
            .scaled(by: scaleFactor)
            .deCollapsed(along: projectionAxis)
    }
}

public protocol Drawable {
    var id: UUID { get }
    var isHidden: Bool { get }

    var occlude: Bool { get }
    var color: NSColor { get }
    var lineWidth: Scalar { get }
    var lines: [Line] { get }
    var spheres: [Sphere] { get }

    var orientation: Quaternion { set get }
    var position: Vector { set get }
}

public class VectorDrawable: Drawable {
    public var vector: Vector { return vectorClosure() }

    public let start: Vector
    public var end: Vector { return start + vector }
    private let vectorClosure: () -> Vector

    public init(_ color: NSColor = .black, at start: Vector, vectorClosure: @escaping () -> Vector) {
        self.color = color
        self.start = start
        self.vectorClosure = vectorClosure
    }

    // MARK - Drawable

    public let id = UUID()

    public var isHidden = false
    public let occlude = false

    public let color: NSColor
    public let lineWidth: Scalar = 3

    public var lines: [Line] {
        return [Line(start: start, end: end)]
    }

    public let spheres: [Sphere] = []

    public var orientation: Quaternion = .id

    public var position: Vector = .origin
}

public class KiteDrawable: Drawable {
    let span: Scalar = 9*1.2
    let length: Scalar = 9*1
    let height: Scalar = 9*0.6

    private let tailProportion: Scalar = 0.8
    private let stabiliserProportion: Scalar = 0.8
    private let stabiliserSize: Scalar = 0.4
    private let rudderSize: Scalar = 0.3

    private let sideWingPlacement: Scalar = 0.5

    // MARK: - Drawable

    public let id = UUID()

    public var isHidden = false

    public let occlude = false

    public var color: NSColor

    public let lineWidth: Scalar = 2

    public var lines: [Line] {
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

    public let spheres = [Sphere(center: .origin, radius: 1)]

    public var orientation: Quaternion = .id

    public var position: Vector = .origin

    public init(position: Vector = .origin, color: NSColor = .black) {
        self.position = position
        self.color = color
    }
}

public class SphereDrawable: Drawable {
    // Parameters

    var radius: Scalar = 50

    // MARK: - Drawable

    public let id = UUID()

    public var isHidden = false

    public var occlude = true

    public let color: NSColor

    public let lineWidth: Scalar = 3

    public var lines: [Line] {
        let longitudes = 20
        let latitudes = 10

        let longDelta = 2*π/Scalar(longitudes)
        let latDelta = (π/2)/Scalar(latitudes)

        var lines = [Line]()
        for i in 0...longitudes {
            let phi = -π/2 + Scalar(i)*longDelta

            for j in 0..<latitudes {
                let theta = π/2 + Scalar(j)*latDelta
                let start = Vector(phi: phi, theta: theta, r: radius)
                let end = Vector(phi: phi, theta: theta + latDelta, r: radius)
                lines.append(Line(start: start, end: end))
            }
        }

        for j in 0..<latitudes {
            let theta = π/2 + Scalar(j)*latDelta
            for i in 0...longitudes {
                let phi = -π/2 + Scalar(i)*longDelta
                let start = Vector(phi: phi, theta: theta, r: radius)
                let end = Vector(phi: phi + longDelta, theta: theta, r: radius)
                lines.append(Line(start: start, end: end))
            }
        }

        return lines
    }

    public let spheres: [Sphere] = []

    public var orientation: Quaternion = .id

    public var position: Vector = .origin

    public init(color: NSColor = NSColor.gray.withAlphaComponent(0.5)) {
        self.color = color
    }
}

public class BallDrawable: Drawable {
    public let id = UUID()

    public var isHidden = false

    public let occlude = false

    public let color: NSColor

    public let lineWidth: Scalar = 0

    public var lines: [Line] = []

    public let spheres: [Sphere]

    public var orientation: Quaternion = .id

    public var position: Vector

    public init(position: Vector = .origin, color: NSColor = .white, radius: Scalar = 2) {
        self.position = position
        self.color = color
        self.spheres = [Sphere(center: .zero, radius: radius)]
    }
}

// 

public class ArrowDrawable: Drawable {
    public let id = UUID()

    public var isHidden = false

    public let occlude = false

    public let color: NSColor

    public var lines: [Line] { return [Line(start: .origin, end: vector)] }

    public let lineWidth: Scalar = 3

    public var spheres: [Sphere] { return hideBall ? [] : [Sphere(center: vector, radius: 2)] }

    public var orientation: Quaternion = .id

    public var position: Vector

    // Special

    public var vector: Vector

    public var hideBall: Bool

    public init(at position: Vector = .origin, vector: Vector = .zero, color: NSColor = .white, hideBall: Bool = false) {
        self.position = position
        self.color = color
        self.vector = vector
        self.hideBall = hideBall
    }
}

public class ArrowsDrawable: Drawable {
    public let id = UUID()

    public var isHidden = false

    public let occlude = false

    public let color: NSColor

    public var lines: [Line] = []

    public let lineWidth: Scalar = 2

    public let spheres: [Sphere] = []

    public var orientation: Quaternion = .id

    public var position: Vector = .origin

    public init(color: NSColor = .black) {
        self.color = color
    }

    public func update(_ positions: [Vector], _ vectors: [Vector]) {
        lines = zip(positions, vectors).map { pos, vec in
            Line(start: pos, end: pos + vec)
        }
    }
}

public class PathDrawable: Drawable {
    public let id = UUID()

    public var isHidden = false

    public let occlude = false

    public let color: NSColor

    public var lines: [Line] = []

    public let lineWidth: Scalar = 2

    public var spheres: [Sphere] = []

    public var orientation: Quaternion = .id

    public var position: Vector = .origin

    public init(color: NSColor = .darkGray) {
        self.color = color
    }

    public func update(_ positions: [Vector]) {
        lines = positions.count >= 2 ? zip(positions.dropLast(), positions.dropFirst()).map(Line.init) : []
//        spheres = positions.map { Sphere(center: $0, radius: 1) }
    }
}

public class BoxDrawable: Drawable {
    public let id = UUID()

    public var isHidden = false

    public let occlude = false

    public let color: NSColor

    public let lineWidth: Scalar = 3

    public let lines: [Line]

    public let spheres: [Sphere] = []

    public var orientation: Quaternion = .id

    public var position: Vector

    public init(at position: Vector = .origin, dx: Scalar, dy: Scalar, dz: Scalar, color: NSColor = .white) {
        self.position = position
        self.color = color

        let corner = (0..<8).map { i in 0.5*Vector(i > 3 ? dx : -dx, i % 4 > 1 ? dy : -dy, i % 2 > 0 ? dz : -dz) }
        lines = [(0, 1), (1, 3), (3, 2), (2, 0), (4, 5), (5, 7), (7, 6), (6, 4), (0, 4), (1, 5), (2, 6), (3, 7)]
            .map { Line(start: corner[$0], end: corner[$1]) }
    }
}

public class ArcDrawable: Drawable {
    // MARK: - Parameters

    var plane: Plane = Plane(center: .origin, normal: e_z)
    var radius: Scalar = 10
    var startAngle: Scalar = 0
    var angle: Scalar

    // MARK: - Private Parameters

    private let points = 30

    // MARK: - Drawable

    public let id = UUID()

    public var isHidden = false

    public let occlude = true

    public let color: NSColor

    public let lineWidth: Scalar = 3

    public var lines: [Line] {
        let vectors = (0...points)
            .map { startAngle + (radius > 0 ? 1 : -1)*angle*Scalar($0)/Scalar(points) }
            .map { plane.deCollapse(point: CGPoint(phi: $0, r: abs(radius))) }

        return zip(vectors.dropLast(), vectors.dropFirst()).map(Line.init)
    }

    public let spheres: [Sphere] = []

    public var orientation: Quaternion = .id

    public var position: Vector = .origin

    public init(angle: Scalar = π/4, color: NSColor = .red) {
        self.angle = angle
        self.color = color
    }
}

public class CircleDrawable: Drawable {
    // MARK: - Parameters

    var radius: Scalar = 20
    var normal: Vector = e_z

    // MARK: - Private Parameters

    private let points = 30

    // MARK: - Drawable

    public let id = UUID()

    public var isHidden = false

    public let occlude = true

    public let color: NSColor

    public let lineWidth: Scalar = 3

    public var lines: [Line] {
        let plane = Plane(center: position, normal: normal)

        func makeVector(phi: Scalar) -> Vector {
            return radius*(sin(phi)*plane.bases.0 + cos(phi)*plane.bases.1)
        }

        let vectors = (0...points)
            .map { 2*π*Scalar($0)/Scalar(points) }
            .map(makeVector)

        return zip(vectors.dropLast(), vectors.dropFirst()).map(Line.init)
    }
    
    public let spheres: [Sphere] = []

    public var orientation: Quaternion = .id
    
    public var position: Vector = .origin

    public init(position: Vector = .origin, color: NSColor = .red) {
        self.position = position
        self.color = color
    }
}
