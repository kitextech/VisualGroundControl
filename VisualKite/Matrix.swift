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

extension Matrix: CustomStringConvertible {
    public static let id = SCNMatrix4Identity
    
    public init(vx: Vector, vy: Vector, vz: Vector) {
        self = Matrix.init(m11: vx.x, m12: vx.y, m13: vx.z, m14: 0,
                           m21: vy.x, m22: vy.y, m23: vy.z, m24: 0,
                           m31: vz.x, m32: vz.y, m33: vz.z, m34: 0,
                           m41: 0, m42: 0, m43: 0, m44: 1)
    }
    
    public init(rotation axis: Vector, by angle: Scalar, translation vector: Vector = .origin, scale: Vector = Vector(1, 1, 1)) {
        self = SCNMatrix4Scale(SCNMatrix4Translate(SCNMatrix4MakeRotation(angle, axis.x, axis.y, axis.z), vector.x, vector.y, vector.z), scale.x, scale.y, scale.z)
    }
    
    public init(translation vector: Vector = .origin, scale: Vector = Vector(1, 1, 1)) {
        self = SCNMatrix4Scale(SCNMatrix4MakeTranslation(vector.x, vector.y, vector.z), scale.x, scale.y, scale.z)
    }

    public func scaled(_ factor: Scalar) -> Matrix {
        return SCNMatrix4Scale(self, factor, factor, factor)
    }
    
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
    
    public static func *(vector: Vector4, matrix: Matrix) -> Vector4 {
        let x = matrix.m11*vector.x + matrix.m21*vector.y + matrix.m31*vector.z + matrix.m41*vector.w
        let y = matrix.m12*vector.x + matrix.m22*vector.y + matrix.m32*vector.z + matrix.m42*vector.w
        let z = matrix.m13*vector.x + matrix.m23*vector.y + matrix.m33*vector.z + matrix.m43*vector.w
        let w = matrix.m14*vector.x + matrix.m24*vector.y + matrix.m34*vector.z + matrix.m44*vector.w
        
        return Vector4(x: x, y: y, z: z, w: w)
    }
    
    public static func *(vector: Vector, matrix: Matrix) -> Vector { 
        let x = matrix.m11*vector.x + matrix.m21*vector.y + matrix.m31*vector.z + matrix.m41
        let y = matrix.m12*vector.x + matrix.m22*vector.y + matrix.m32*vector.z + matrix.m42
        let z = matrix.m13*vector.x + matrix.m23*vector.y + matrix.m33*vector.z + matrix.m43
        
//        print("*: vector: \(vector.description) * m = \(Vector(x: x, y: y, z: z).description), m = \n\(matrix.description)")
        
        return Vector(x: x, y: y, z: z)
    }
    
    // Scalar multiplication
    
    public static func *(scalar: Scalar, matrix: Matrix) -> Matrix {
        return Matrix(
            m11: scalar*matrix.m11, m12: scalar*matrix.m12, m13: scalar*matrix.m13, m14: scalar*matrix.m14,
            m21: scalar*matrix.m21, m22: scalar*matrix.m22, m23: scalar*matrix.m23, m24: scalar*matrix.m24,
            m31: scalar*matrix.m31, m32: scalar*matrix.m32, m33: scalar*matrix.m33, m34: scalar*matrix.m34,
            m41: scalar*matrix.m41, m42: scalar*matrix.m42, m43: scalar*matrix.m43, m44: scalar*matrix.m44)
    }
    
//    public static func *(int: Int, matrix: Matrix) -> Matrix {
//        return Scalar(int)*matrix
//    }
    
    public static func *=(matrix: inout Matrix, scalar: Scalar) {
        matrix = scalar*matrix
    }
    
//    public static func *=(matrix: inout Matrix, int: Int) {
//        matrix = int*matrix
//    }

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
