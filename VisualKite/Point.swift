//
//  Point.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-06-30.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import Foundation

let π = Scalar(Double.pi)

extension CGPoint {
    init(phi: Scalar, r: Scalar) {
        self = r*CGPoint(x: cos(phi), y: sin(phi))
    }

    static func *(left: Scalar, right: CGPoint) -> CGPoint {
        return CGPoint(x: CGFloat(left)*right.x, y: CGFloat(left)*right.y)
    }

    static func •(left: CGPoint, right: CGPoint) -> Scalar {
        return  Scalar(left.x*right.x + left.y*right.y)
    }

    static func +(left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x + right.x, y: left.y + right.y)
    }

    static func -(left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x - right.x, y: left.y - right.y)
    }

    static prefix func -(point: CGPoint) -> CGPoint {
        return CGPoint(x: -point.x, y: -point.y)
    }

    public var norm: Scalar {
        return Scalar(sqrt(x*x + y*y))
    }

    public var phi: Scalar {
        return Scalar(atan2(y, x))
    }

    public var r: Scalar {
        return norm
    }

    public var normSquared: Scalar {
        return Scalar(x*x + y*y)
    }

    public var unit: CGPoint {
        return (1/norm)*self
    }

    public func angle(to point: CGPoint) -> Scalar {
        return acos(unit•point.unit)
    }

    public func signedAngle(to point: CGPoint) -> Scalar {
        let p = point.unit
        let q = unit

        let signed = Scalar(asin(p.y*q.x - p.x*q.y))

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

    public func rotated(by angle: Scalar) -> CGPoint {
        return self.applying(CGAffineTransform(rotationAngle: CGFloat(angle)))
    }

    public func deCollapsed(on plane: (x: Vector, y: Vector)) -> Vector {
        return Scalar(x)*plane.x + Scalar(y)*plane.y
    }

    public func deCollapsed(along axis: Vector) -> Vector {
        if axis == e_z {
            return Vector(x, y, 0)
        }

        return deCollapsed(on: Plane(center: .origin, normal: axis).bases)
    }

    public func scaled(by factor: Scalar) -> CGPoint {
        return CGPoint(x: CGFloat(factor)*x, y: CGFloat(factor)*y)
    }

    public func absolute(in rect: CGRect) -> CGPoint {
        return CGPoint(x: rect.maxX - rect.width*(0.5 + x), y: rect.minY + rect.height*(0.5 + y))
    }

    public func relative(in rect: CGRect) -> CGPoint {
        return CGPoint(x: (rect.maxX - x)/rect.width - 0.5, y: (y - rect.minY)/rect.height - 0.5)
    }

    public var size: CGSize {
        return CGSize(width: x, height: y)
    }
}

extension CGSize {
    init(side: CGFloat) {
        self = CGSize(width: side, height: side)
    }

    public var point: CGPoint {
        return CGPoint(x: width, y: height)
    }

    public func scaled(by factor: Scalar) -> CGSize {
        return CGSize(width: factor*width, height: factor*height)
    }

    public func absolute(in rect: CGRect) -> CGSize {
        return CGSize(width: rect.width*width, height: rect.height*height)
    }

    public func relative(in rect: CGRect) -> CGSize {
        return CGSize(width: width/rect.width, height: height/rect.height)
    }
}

extension CGRect {
    init(center: CGPoint, size: CGSize) {
        self = CGRect(origin: center - CGPoint(x: size.width/2, y: size.height/2), size: size)
    }
    
    public static var unit: CGRect {
        return CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    public var center: CGPoint { return CGPoint(x: midX, y: midY) }
}
