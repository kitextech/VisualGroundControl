//
//  Matrix4.swift
//  SKLinearAlgebra
//
//  Created by Cameron Little on 2/24/15.
//  Copyright (c) 2015 Cameron Little. All rights reserved.
//

import Accelerate
import Foundation
import SceneKit

public typealias Scalar = SCNFloat
public typealias Vector = SCNVector3
public typealias Vector4 = SCNVector4
public typealias Matrix = SCNMatrix4

extension Matrix {
    public init(rotation axis: Vector, by angle: Scalar, translation vector: Vector) {
        self = SCNMatrix4Translate(SCNMatrix4MakeRotation(angle, axis.x, axis.y, axis.z), vector.x, vector.y, vector.z)
    }
    
    public init(rotation axis: Vector, by angle: Scalar) {
        self = SCNMatrix4MakeRotation(angle, axis.x, axis.y, axis.z)
    }
    
    public init(translation vector: Vector) {
        self = SCNMatrix4MakeTranslation(vector.x, vector.y, vector.z)
    }
    
//    public static func rotation(around vector: Vector, by angle: Scalar) -> Matrix {
//        return SCNMatrix4MakeRotation(angle, vector.x, vector.y, vector.z)
//    }
//
//    public static func translation(by vector: Vector) -> Matrix {
//        return SCNMatrix4MakeTranslation(vector.x, vector.y, vector.z)
//    }
//
//    public func rotated(around vector: Vector, by angle: Scalar) -> Matrix {
//        return SCNMatrix4Rotate(self, angle, vector.x, vector.y, vector.z)
//    }
//
//    public func translated(by vector: Vector) -> Matrix {
//        return SCNMatrix4Translate(self, vector.x, vector.y, vector.z)
//    }

    subscript(row: Int, col: Int) -> Scalar {
        get {
            assert(0 <= row && row < 4 && 0 <= col && col < 4, "Index out of range")
            switch (row, col) {
            case (0, 0): return m11
            case (0, 1): return m12
            case (0, 2): return m13
            case (0, 3): return m14

            case (1, 0): return m21
            case (1, 1): return m22
            case (1, 2): return m23
            case (1, 3): return m24

            case (2, 0): return m31
            case (2, 1): return m32
            case (2, 2): return m33
            case (2, 3): return m34

            case (3, 0): return m41
            case (3, 1): return m42
            case (3, 2): return m43
            case (3, 3): return m44
            default: fatalError("Index out of range")
            }
        }
        set {
            assert((0 <= row && row < 4) && (0 <= col && col < 4), "Index out of range")
            switch (row, col) {
            case (0, 0): m11 = newValue
            case (0, 1): m12 = newValue
            case (0, 2): m13 = newValue
            case (0, 3): m14 = newValue
                
            case (1, 0): m21 = newValue
            case (1, 1): m22 = newValue
            case (1, 2): m23 = newValue
            case (1, 3): m24 = newValue
                
            case (2, 0): m31 = newValue
            case (2, 1): m32 = newValue
            case (2, 2): m33 = newValue
            case (2, 3): m34 = newValue
                
            case (3, 0): m41 = newValue
            case (3, 1): m42 = newValue
            case (3, 2): m43 = newValue
            case (3, 3): m44 = newValue
            default: fatalError("Index out of range")
            }
        }
    }
    
    public var description: String {
        return "[[\(m11), \(m12), \(m13), \(m14)]\n" +
            " [\(m21), \(m22), \(m23), \(m24)]\n" +
            " [\(m31), \(m32), \(m33), \(m34)]\n" +
            " [\(m41), \(m42), \(m43), \(m44)]]"
    }
    
    public var array: [[Scalar]] {
        return [[m11, m12, m13, m14],
                [m21, m22, m23, m24],
                [m31, m32, m33, m34],
                [m41, m42, m43, m44]]
    }
    
    public var transpose: Matrix {
        return Matrix(m11: m11, m12: m21, m13: m31, m14: m41,
                      m21: m12, m22: m22, m23: m32, m24: m42,
                      m31: m13, m32: m23, m33: m33, m34: m43,
                      m41: m14, m42: m24, m43: m34, m44: m44)
    }
    
    public static func ==(lhs: Matrix, rhs: Matrix) -> Bool {
        return SCNMatrix4EqualToMatrix4(lhs, rhs)
    }
    
    // Matrix multiplication

    public static func *(left: Matrix, right: Matrix) -> Matrix {
        return SCNMatrix4Mult(left, right)
    }

    // Matrix vector multiplication
    
    public static func *(matrix: Matrix, vector: Vector4) -> Vector4 {
        let x = matrix.m11*vector.x + matrix.m21*vector.y + matrix.m31*vector.z + matrix.m41*vector.w
        let y = matrix.m12*vector.x + matrix.m22*vector.y + matrix.m32*vector.z + matrix.m42*vector.w
        let z = matrix.m13*vector.x + matrix.m23*vector.y + matrix.m33*vector.z + matrix.m43*vector.w
        let w = matrix.m14*vector.x + matrix.m24*vector.y + matrix.m34*vector.z + matrix.m44*vector.w
        
        return Vector4(x: x, y: y, z: z, w: w)
    }
    
    public static func *(matrix: Matrix, vector: Vector) -> Vector {
        let x = matrix.m11*vector.x + matrix.m21*vector.y + matrix.m31*vector.z + matrix.m41
        let y = matrix.m12*vector.x + matrix.m22*vector.y + matrix.m32*vector.z + matrix.m42
        let z = matrix.m13*vector.x + matrix.m23*vector.y + matrix.m33*vector.z + matrix.m43
        
        return Vector(x: x, y: y, z: z)
    }
    
    // Scalar multiplication
    
    public static func *(matrix: Matrix, scalar: Scalar) -> Matrix {
        return Matrix(
            m11: matrix.m11*scalar, m12: matrix.m12*scalar, m13: matrix.m13*scalar, m14: matrix.m14*scalar,
            m21: matrix.m21*scalar, m22: matrix.m22*scalar, m23: matrix.m23*scalar, m24: matrix.m24*scalar,
            m31: matrix.m31*scalar, m32: matrix.m32*scalar, m33: matrix.m33*scalar, m34: matrix.m34*scalar,
            m41: matrix.m41*scalar, m42: matrix.m42*scalar, m43: matrix.m43*scalar, m44: matrix.m44*scalar)
    }
    
    public static func *(scalar: Scalar, matrix: Matrix) -> Matrix {
        return matrix*scalar
    }
    
    public static func *(matrix: Matrix, int: Int) -> Matrix {
        return matrix*Scalar(int)
    }
    
    public static func *(int: Int, matrix: Matrix) -> Matrix {
        return matrix*Scalar(int)
    }
    
    public static func *=(matrix: inout Matrix, scalar: Scalar) {
        matrix = matrix*scalar
    }
    
    public static func *=(matrix: inout Matrix, int: Int) {
        matrix = matrix*int
    }

}

//public func inverse(m: SCNMatrix4) -> SCNMatrix4 {
//    // https://github.com/mattt/Surge/
//
//    var results = [Float](count: 16, repeatedValue: 0.0)
//
//    var grid = m.linearFloatArray
//
//    var ipiv = [__CLPK_integer](count: 16, repeatedValue: 0)
//    var lwork = __CLPK_integer(16)
//    var work = [CFloat](count: Int(lwork), repeatedValue: 0.0)
//    var error: __CLPK_integer = 0
//    var nc = __CLPK_integer(4)
//
//    sgetrf_(&nc, &nc, &(grid), &nc, &ipiv, &error)
//    sgetri_(&nc, &(grid), &nc, &ipiv, &work, &lwork, &error)
//
//    assert(error == 0, "MatrixFloat not invertible")
//
//    return SCNMatrix4(grid)
//}
