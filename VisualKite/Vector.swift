//
//  Vector.swift
//  SKLinearAlgebra
//
//  Created by Cameron Little on 2/24/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import Foundation
import SceneKit

infix operator •: MultiplicationPrecedence
infix operator ×: MultiplicationPrecedence

extension Vector {
    // Creation
    
    public static var zero: Vector {
        return SCNVector3Zero
    }
    
    public static var origin: Vector {
        return Vector(x: 0, y: 0, z: 0)
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
        return Matrix(rotation: vector, by: angle)*self
    }
    
    public func transformed(by matrix: Matrix) -> Vector {
        return matrix*self
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
    
    public func projection(on b: Vector) -> Vector {
        let normB = b.norm
        
        guard normB > 0 else {
            fatalError("Zero vector provided to projection")
        }

        return (self•b/pow(normB, 2))*b
    }

    public func angle(with b: Vector) -> Scalar {
        let m = norm*b.norm
        
        guard m > 0 else {
            fatalError("Zero vector provided to angle")
        }
        
        return acos(self•b/m)
    }

    public var norm: Scalar {
        return sqrt(self•self)
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

    // Scalar multiplication
    
    public static func *(scalar: Scalar, vector: Vector) -> Vector {
        let x = scalar*vector.x
        let y = scalar*vector.y
        let z = scalar*vector.z
        
        return Vector(x: x, y: y, z: z)
    }
    
//    public static func *(int: Int, vector: Vector) -> Vector {
//        return Scalar(int)*vector
//    }

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
