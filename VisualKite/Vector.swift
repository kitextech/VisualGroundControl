//
//  Vector.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-06-30.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import Foundation
import SceneKit

public struct Line {
    let start: Vector
    let end: Vector

    func translated(_ vector: Vector) -> Line {
        return Line(start: start + vector, end: end + vector)
    }

    func rotated(_ q: Quaternion) -> Line {
        return Line(start: start.rotated(q), end: end.rotated(q))
    }

    func scaled(_ scalar: Scalar) -> Line {
        return Line(start: scalar*start, end: scalar*end)
    }

    func split(by p: Plane) -> (pos: Line, neg: Line) {
        let rho = (p.center - start)•p.normal/((end - start)•p.normal)
        let x = start + rho*(end - start)
        let l1 = Line(start: start, end: x)
        let l2 = Line(start: x, end: end)

        return (start - p.center)•p.normal > 0 ? (l1, l2) : (l2, l1)
    }
}

extension Line {
    public static func *(scalar: Scalar, line: Line) -> Line {
        return line.scaled(scalar)
    }

    public static func +(line: Line, translation: Vector) -> Line {
        return line.translated(translation)
    }

    public static func -(line: Line, translation: Vector) -> Line {
        return line.translated(-translation)
    }

    // MARK: - Higher order functions

    public static func translator(by v: Vector) -> (Line) -> Line {
        return { $0 + v }
    }
}

public struct Sphere {
    let center: Vector
    let radius: Scalar

    public static var unit: Sphere { return Sphere(center: .origin, radius: 1) }

    public func spherify(vector: Vector, along normal: Vector) -> Vector {
        let v = vector - center

        guard v.norm < radius else {
            return radius*v.unit + center
        }

        let n = normal == -e_z ? normal : -normal

        return v + sqrt(radius*radius - v.squaredNorm)*n + center
    }

    public func translated(_ vector: Vector) -> Sphere {
        return Sphere(center: center + vector, radius: radius)
    }
}

public struct Plane {
    let center: Vector
    let normal: Vector

    public static var z = Plane(center: .origin, normal: e_z)

    public var bases: (Vector, Vector) {
        if normal || e_z {
            return (e_y, e_x)
        }

        let x = (e_z×normal).unit
        let y = x×normal

        return (x, y)
    }

    public static func getCenter(plane: Plane) -> Vector {
        return plane.center
    }

    public func occlude(line: Line) -> Line? {
        let line2 = line - center
        switch (line2.start•normal > 0, line2.end•normal > 0) {
        case (true, true): return nil
        case (false, false): return line
        case (true, false), (false, true): return line.split(by: self).neg
        }
    }
}

infix operator •: MultiplicationPrecedence
infix operator ×: MultiplicationPrecedence
infix operator -|: MultiplicationPrecedence

infix operator >>>: MultiplicationPrecedence

// x >> sin >> cos = (x >> sin) >> cos

func >><T, S>(argument: T, function: (T) -> S) -> S {
    return function(argument)
}

extension Vector: CustomStringConvertible, Equatable {
    // Creation

    public static func fromScalars(_ x: Scalar, y: Scalar, z: Scalar) -> Vector {
        return Vector(x, y, z)
    }

    public static var zero: Vector {
        return SCNVector3Zero
    }
    
    public static var origin: Vector {
        return SCNVector3Zero
    }

    public static var ex: Vector {
        return Vector(x: 1, y: 0, z: 0)
    }
    
    public static var ey: Vector {
        return Vector(x: 0, y: 1, z: 0)
    }
    
    public static var ez: Vector {
        return Vector(x: 0, y: 0, z: 1)
    }

    public static func unitVector(phi: Scalar, theta: Scalar) -> Vector {
        return Vector(phi: phi, theta: theta, r: 1)
    }

    public init(phi: Scalar, theta: Scalar, r: Scalar) {
        let x = r*sin(theta)*cos(phi)
        let y = r*sin(theta)*sin(phi)
        let z = r*cos(theta)
        self = Vector(x, y, z)
    }

    public init(_ array: [Scalar]) {
        assert(array.count == 3)

        x = array[0]
        y = array[1]
        z = array[2]
    }

    public var v4: Vector4 {
        return Vector4(x: x, y: y, z: z, w: 1)
    }

    public var description: String {
        return "[\(x), \(y), \(z)]"
    }

    subscript(i: Int) -> Scalar {
        assert(0 <= i && i < 3, "Index out of range")
        switch i {
        case 0: return x
        case 1: return y
        case 2: return z
        default: fatalError()
        }
    }
    
    // Manipulation
    
    public func translated(by vector: Vector) -> Vector {
        return self + vector
    }
    
    public func rotated(around vector: Vector, by angle: Scalar) -> Vector {
        return self*Matrix(rotation: vector.unit, by: angle)
    }

    public func rotated(_ quaternion: Quaternion) -> Vector {
        return quaternion.apply(self)
    }

    public func transformed(by matrix: Matrix) -> Vector {
        return self*matrix
    }
    
    // Properties
    
    public var r: Scalar {
        return norm
    }

    public var phi: Scalar {
        return atan2(y, x)
    }

    public var theta: Scalar {
        return atan2(z, sqrt(x*x + y*y))
    }

    public func component(along b: Vector) -> Scalar {
        let normB = b.norm
        
        guard normB > 0 else {
            fatalError("Zero vector provided to component")
        }
        return self•b/normB
    }
    
    public func projected(on b: Vector) -> Vector {
        let normB = b.norm
        
        guard normB > 0 else {
            fatalError("Zero vector provided to projection")
        }

        return (self•b/pow(normB, 2))*b
    }

    public func projected(on plane: Plane) -> Vector {
        return self - projected(on: plane.normal)
    }

    // Collapsed to point

    public func collapsed(along axis: Vector) -> CGPoint {
        if axis || e_z {
            return CGPoint(x: y, y: x)
        }

        let bases = Plane(center: .origin, normal: axis).bases

        return collapsed(on: bases)
    }

    public func collapsed(on bases: (x: Vector, y: Vector)) -> CGPoint {
        return CGPoint(x: component(along: bases.x), y: component(along: bases.y))
    }

    // Angles and norms

    public func angle(to b: Vector) -> Scalar {
        let m = norm*b.norm
        
        guard m > 0 else {
            fatalError("Zero vector provided to angle")
        }
        
        return acos(self•b/m)
    }

    public var norm: Scalar {
        return sqrt(squaredNorm)
    }
    
    public var squaredNorm: Scalar {
        return self•self
    }

    public func distance(to sphere: Sphere) -> Scalar {
        return (self - sphere.center).norm - sphere.radius
    }

    public var unit: Vector {
        let r = norm
        
        guard r > 0 else {
            fatalError("Norm is zero")
        }
        
        return (1/r)*self
    }

    // Dot product

    public static func •(left: Vector, right: Vector) -> Scalar {
        return left.x*right.x + left.y*right.y + left.z*right.z
    }
    
    // Cross product
    
    public static func ×(left: Vector, right: Vector) -> Vector {
        let x = left.y*right.z - left.z*right.y
        let y = left.z*right.x - left.x*right.z
        let z = left.x*right.y - left.y*right.x
        
        return Vector(x: x, y: y, z: z)
    }

    // Equality

    public static func ==(lhs: Vector, rhs: Vector) -> Bool {
        return SCNVector3EqualToVector3(lhs, rhs)
    }

    // Parallel

    public static func ||(lhs: Vector, rhs: Vector) -> Bool {
        return lhs×rhs == .zero
    }

    public static func ||(lhs: Vector, rhs: Plane) -> Bool {
        return lhs -| rhs.normal
    }

    public static func ||(lhs: Plane, rhs: Vector) -> Bool {
        return rhs || lhs
    }

    // Perpendicular

    public static func -|(lhs: Vector, rhs: Vector) -> Bool {
        return lhs•rhs == 0
    }

    public static func -|(lhs: Vector, rhs: Plane) -> Bool {
        return lhs || rhs.normal
    }

    public static func -|(lhs: Plane, rhs: Vector) -> Bool {
        return rhs -| lhs
    }

    // Scalar multiplication
    
    public static func *(scalar: Scalar, vector: Vector) -> Vector {
        let x = scalar*vector.x
        let y = scalar*vector.y
        let z = scalar*vector.z
        
        return Vector(x: x, y: y, z: z)
    }

    public static func *(vector: Vector, scalar: Scalar) -> Vector {
        return scalar*vector
    }

//    public static func *(int: Int, vector: Vector) -> Vector {
//        return Scalar(int)*vector
//    }

    // Scalar division

    public static func /(lhs: Vector, rhs: Scalar) -> Vector {
        return Vector(x: lhs.x/rhs, y: lhs.y/rhs, z: lhs.z/rhs)
    }

    // Vector addition
    
    public static func +(left: Vector, right: Vector) -> Vector {
        let x = left.x + right.x
        let y = left.y + right.y
        let z = left.z + right.z
        
        return Vector(x: x, y: y, z: z)
    }
    
    public static func +=(left: inout Vector, right: Vector) {
        left = left + right
    }

    // Vector subtraction
    
    public static func -(left: Vector, right: Vector) -> Vector {
        let x = left.x - right.x
        let y = left.y - right.y
        let z = left.z - right.z
        
        return Vector(x: x, y: y, z: z)
    }
    
    public static func -=(left: inout Vector, right: Vector) {
        left = left - right
    }

    // Vector negation
    
    public static prefix func -(vector: Vector) -> Vector {
        let x = -vector.x
        let y = -vector.y
        let z = -vector.z
        
        return Vector(x: x, y: y, z: z)
    }
}
