//
//  Vector4.swift
//  SKLinearAlgebra
//
//  Created by Cameron Little on 2/24/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import Foundation
import SceneKit

public typealias Rotation = Vector4

extension Rotation {
    init(around vector: Vector, by angle: Scalar) {
        self = Vector4(x: vector.x, y: vector.y, z: vector.z, w: angle)
    }
}

extension Vector4 {
    // Creation
    
    public static var id: Vector4 {
        return Vector4(x: 0, y: 0, z: 0, w: 1)
    }

    public static var zero: Vector4 {
        return SCNVector4Zero
    }
    
    public static var ex: Vector4 {
        return Vector4(x: 1, y: 0, z: 0, w: 1)
    }

    public static var ey: Vector4 {
        return Vector4(x: 0, y: 1, z: 0, w: 1)
    }

    public static var ez: Vector4 {
        return Vector4(x: 0, y: 0, z: 1, w: 1)
    }
    
    public init(_ array: [Scalar]) {
        assert(array.count == 4)

        x = array[0]
        y = array[1]
        z = array[2]
        w = array[3]
    }

    // Conversion

    public var v3: Vector {
        return Vector(x: x, y: y, z: z)
    }

    public func copy() -> Vector4 {
        return Vector4(x: x, y: y, z: z, w: w)
    }

    public var description: String {
        return "[\(x), \(y), \(z), \(w)]"
    }
    
    // Elements
    
    subscript(i: Int) -> Scalar {
        get {
            assert(0 <= i && i < 4, "Vector index out of range")
            switch i {
            case 0: return x
            case 1: return y
            case 2: return z
            case 3: return w
            default: fatalError()
            }
        }
        set {
            assert(0 <= i && i < 4, "Vector index out of range")
            switch i {
            case 0: x = newValue
            case 1: y = newValue
            case 2: z = newValue
            case 3: w = newValue
            default: fatalError()
            }
        }
    }
    
    // Equality

    public static func ==(lhs: Vector4, rhs: Vector4) -> Bool {
        return SCNVector4EqualToVector4(lhs, rhs)
    }
    
    // Dot product
    
    public static func •(left: Vector4, right: Vector4) -> Scalar {
        return left.x*right.x + left.y*right.y + left.z*right.z
    }

    // Cross product
    
    public static func ×(left: Vector4, right: Vector4) -> Vector4 {
        let x = left.y*right.z - left.z*right.y
        let y = left.z*right.x - left.x*right.z
        let z = left.x*right.y - left.y*right.x
        let w = left.w*right.w // TODO: Check
        
        return Vector4(x: x, y: y, z: z, w: w)
    }

    // Scalar multiplication
    
    public static func *(scalar: Scalar, vector: Vector4) -> Vector4 {
        let x = scalar*vector.x
        let y = scalar*vector.y
        let z = scalar*vector.z
        let w = vector.w // TODO: Check
        
        return Vector4(x: x, y: y, z: z, w: w)
    }
    
    public static func *(int: Int, vector: Vector4) -> Vector4 {
        return Scalar(int)*vector
    }
    
    // Vector addition
    
    public static func +(left: Vector4, right: Vector4) -> Vector4 {
        let x = left.x + right.x
        let y = left.y + right.y
        let z = left.z + right.z
        
        let w = left.w*right.w
        
        return Vector4(x: x, y: y, z: z, w: w)
    }
    
    // Vector subtraction
    
    public static func -(left: Vector4, right: Vector4) -> Vector4 {
        let x = left.x - right.x
        let y = left.y - right.y
        let z = left.z - right.z
        let w = left.w/right.w // TODO: Check
        
        return Vector4(x: x, y: y, z: z, w: w)
    }

    public static prefix func -(vector: Vector4) -> Vector4 {
        return Vector4(x: -vector.x, y: -vector.y, z: -vector.z, w: vector.w) // TODO: Check
    }
}


