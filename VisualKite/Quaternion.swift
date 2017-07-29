//
//  Quaternion.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-18.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import Foundation
import SceneKit

extension Vector4 {
    public static func rotationVector(axis: Vector, angle: Scalar) -> Vector4 {
        return Vector4(x: axis.x, y: axis.y, z: axis.z, w: angle)
    }
}

extension Quaternion: Equatable {
    // Creation

    init(axis: Vector, angle: Scalar) {
        self = cos(angle/2) + axis*sin(angle/2)
    }

    init(_ vector: Vector) {
        self = Quaternion(vector.x, vector.y, vector.z, 0)
    }

    init(_ scalar: Scalar) {
        self = Quaternion(0, 0, 0, scalar)
    }

    public static var zero: Quaternion {
        return SCNVector4Zero
    }

    public static var id: Quaternion {
        return Quaternion(x: 0, y: 0, z: 0, w: 1)
    }

    public static var i: Quaternion {
        return Quaternion(x: 1, y: 0, z: 0, w: 0)
    }

    public static var j: Quaternion {
        return Quaternion(x: 0, y: 1, z: 0, w: 0)
    }

    public static var k: Quaternion {
        return Quaternion(x: 0, y: 0, z: 1, w: 0)
    }

    public var description: String {
        return "[\(x), \(y), \(z), \(w)]"
    }

    // Application

//    public func apply(_ vec: Vector) -> Vector {
//        let q = self
//        let v = Quaternion(vec)
//        return (q*v*q.conjugate).vector
//    }

    public func apply(_ v: Vector) -> Vector {
        let t = 2*vector×v
        return v + scalar*t + vector×t
    }

    public func apply(_ line: Line) -> Line {
        return Line(start: apply(line.start), end: apply(line.end))
    }

    // Equality

    public static func ==(lhs: Quaternion, rhs: Quaternion) -> Bool {
        return SCNVector4EqualToVector4(lhs, rhs)
    }

    // Parts

    public var scalar: Scalar {
        get { return w }
        set { w = newValue }
    }

    public var vector: Vector {
        get { return Vector(x, y, z) }
        set { (x, y, z) = (newValue.x, newValue.y, newValue.z) }
    }

    // Conjugate

    public var conjugate: Quaternion {
        return Quaternion(-x, -y, -z, w)
    }

    // Inverse

    public var inverse: Quaternion {
        assert(self != .zero)
        return conjugate/(scalar*scalar + vector•vector)
    }

    // Multiplication

    static func *(left: Quaternion, right: Quaternion) -> Quaternion {
        let scalar = left.scalar*right.scalar - left.vector•right.vector
        let vector = left.scalar*right.vector + left.vector*right.scalar + left.vector×right.vector
        return scalar + vector
    }

    // Division

    static func /(left: Quaternion, right: Quaternion) -> Quaternion {
        return left*right.inverse
    }

    // Addition

    static func +(left: Quaternion, right: Quaternion) -> Quaternion {
        return Quaternion(left.x + right.x, left.y + right.y, left.z + right.z, left.w + right.w)
    }

    // Subtraction

    static func -(left: Quaternion, right: Quaternion) -> Quaternion {
        return Quaternion(left.x - right.x, left.y - right.y, left.z - right.z, left.w - right.w)
    }

    // Negation

    static prefix func -(q: Quaternion) -> Quaternion {
        return Quaternion(-q.x, -q.y, -q.z, -q.w)
    }

    // Scalar Multiplication

    public static func *(scalar: Scalar, vector: Quaternion) -> Quaternion {
        let x = scalar*vector.x
        let y = scalar*vector.y
        let z = scalar*vector.z
        let w = scalar*vector.w

        return Quaternion(x: x, y: y, z: z, w: w)
    }

    public static func *(vector: Quaternion, scalar: Scalar) -> Quaternion {
        return scalar*vector
    }

    public static func *(int: Int, vector: Quaternion) -> Quaternion {
        return Scalar(int)*vector
    }

    // Scalar Division

    public static func /(vector: Quaternion, scalar: Scalar) -> Quaternion {
        assert(scalar != 0)
        return (1/scalar)*vector
    }
}

func +(left: Vector, right: Scalar) -> Quaternion {
    return Quaternion(left) + Quaternion(right)
}

func -(left: Vector, right: Scalar) -> Quaternion {
    return Quaternion(left) - Quaternion(right)
}

func +(left: Scalar, right: Vector) -> Quaternion {
    return Quaternion(left) + Quaternion(right)
}

func -(left: Scalar, right: Vector) -> Quaternion {
    return Quaternion(left) - Quaternion(right)
}



