//
//  Euler.swift
//  VisualKite
//
//  Created by Andreas Okholm on 28/08/2017.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import Foundation


// param phi_ rotation angle about X axis
// param theta_ rotation angle about Y axis
// param psi_ rotation angle about Z axis

struct Euler {
    let phi: Float //
    let theta: Float
    let psi: Float
    
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
