//
//  Euler.swift
//  VisualKite
//
//  Created by Andreas Okholm on 28/08/2017.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import Foundation

struct Euler {
    let phi: Float // rotation angle about X axis
    let theta: Float // rotation angle about Y axis
    let psi: Float // rotation angle about Z axis

    init(dcm: Matrix) {
        var phi_val = Float(atan2(dcm[2, 1], dcm[2, 2]))
        let theta_val = Float(asin(-dcm[2, 0]))
        var psi_val = Float(atan2(dcm[1, 0], dcm[0, 0]))

        if ( fabs(theta_val - Float.pi / 2) < 1.0e-3) {
            phi_val = 0
            psi_val = Float( atan2(dcm[1, 2], dcm[0, 2]) )

        } else if (fabs(theta_val + Float.pi / 2) < 1.0e-3) {
            phi_val = 0
            psi_val = Float( atan2(-dcm[1, 2], -dcm[0, 2]) )
        }

        self.phi = phi_val
        self.theta = theta_val
        self.psi = psi_val

    }

    init(q: Quaternion) {
        self.init(dcm: Matrix(quaternion: q ))
    }
}

struct Euler2 {
    let phi: Float // rotation about X axis
    let theta: Float // rotation about Y axis
    let psi: Float // rotation about Z axis

    init(dcm: Matrix) {
        theta = Float(asin(-dcm[2, 0]))

        if fabs(theta - .pi/2) < 1.0e-3 {
            phi = 0
            psi = Float(atan2(dcm[1, 2], dcm[0, 2]) )
        }
        else if fabs(theta + .pi/2) < 1.0e-3 {
            phi = 0
            psi = Float(atan2(-dcm[1, 2], -dcm[0, 2]) )
        }
        else {
            phi = Float(atan2(dcm[2, 1], dcm[2, 2]))
            psi = Float(atan2(dcm[1, 0], dcm[0, 0]))
        }
    }

    init(q: Quaternion) {
        self.init(dcm: Matrix(quaternion: q ))
    }
}

