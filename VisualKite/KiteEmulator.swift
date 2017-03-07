//
//  KiteEmulator.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-02-28.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import Foundation
import RxSwift

final class KiteEmulator: KiteType {
    private let updateFrequency: Double = 20
    private var totalElapsed: TimeInterval = 0
    
    private let bag = DisposeBag()
    
    // MARK: Input Variables
    
    // Meta
    public let phiDelta = Variable<Scalar>(0)
    public let rollDelta = Variable<Scalar>(0)
    public let pitchDelta = Variable<Scalar>(0)
    public let speedFactor = Variable<Scalar>(3)
    public let phaseDelta = Variable<Scalar>(0)

    // Kite
    public let gamma = Variable<Scalar>(π/8)
    public let tetherLength = Variable<Scalar>(100)
    public let turningRadius = Variable<Scalar>(20)
    
    // Wind
    public let wind = Variable<Vector>(10*e_x)
    
    // MARK: Intermediate Variables
    
    private var phi: Scalar { return getWindPhi(wind: wind.value) + phiDelta.value }
    private var theta: Scalar { return getTheta(gamma: gamma.value) }
    private var d: Scalar { return getD(l: tetherLength.value, r: turningRadius.value) }

    private var phase: Scalar = 0
    
    // MARK: Ouput Variables
    
    // KiteDataProvider
    
    public let position = PublishSubject<Vector>()
    public let attitude = PublishSubject<Matrix>()
    public let velocity = PublishSubject<Vector>()
    
    // KiteDataAnalyser
    
    public let turningPoint = PublishSubject<Vector>()
    
    public init() {
        // Emulator Input
    }
    
    public func update(elapsed: TimeInterval) {
        totalElapsed += elapsed
        if totalElapsed >= 1/updateFrequency {
            update(totalElapsed: totalElapsed)
            totalElapsed = 0
        }
    }
    
    public func update() {
        update(totalElapsed: totalElapsed)
    }

    private func update(totalElapsed: TimeInterval) {
        // Find C
        let m_phi = Matrix(rotation: .ez, by: phi)
        let m_theta = Matrix(rotation: .ey, by: theta)
        let m = m_theta*m_phi
        
        let c = d*(e_z*m)
        
        turningPoint.onNext(c)

        // Find ∏
        
        let e_πy = e_y*m

        // Place kite
        
        let speed = speedFactor.value*wind.value.component(along: c)
        let omega = speed/turningRadius.value
        phase += omega*Scalar(totalElapsed)
        
        let e_kite = e_πy.rotated(around: c, by: phase + phaseDelta.value)
        let pos = c + turningRadius.value*e_kite
        let vel = speed*c.unit×e_kite

        position.onNext(pos)
        velocity.onNext(vel)
        
        let apparent = wind.value - vel
        
        if apparent.norm == 0 || pos.norm == 0 { return }
        
        let e_p = pos.unit
        let e_kx = -apparent.unit
        let e_ky = -e_kx×e_p
        let e_kz = e_kx×e_ky
        
        let e_kx_adj = e_kx.rotated(around: e_ky, by: pitchDelta.value)
        let e_ky_adj = e_ky.rotated(around: e_kx, by: rollDelta.value)
        let e_kz_adj = e_kx_adj×e_ky_adj

        let att = Matrix(vx: e_kx_adj, vy: e_ky_adj, vz: e_kz_adj)

        attitude.onNext(att)
    }
    
    // Helper Methods - Pure
    
    private func getD(l: Scalar, r: Scalar) -> Scalar {
        return sqrt(l*l - r*r)
    }
    
    private func getTheta(gamma: Scalar) -> Scalar {
        return π/2 - gamma
    }
    
    private func getWindPhi(wind: Vector) -> Scalar {
        return e_x.angle(to: wind)
    }
}

