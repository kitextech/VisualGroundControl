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
    
    private let bag = DisposeBag()
    
    // MARK: Input Variables
    
    // Meta
    public let speedFactor = Variable<Scalar>(3)
    public let rollDelta = Variable<Scalar>(0)
    public let phaseDelta = Variable<Scalar>(0)
    public let phiDelta = Variable<Scalar>(0)

    // Kite
    public let gamma = Variable<Scalar>(0)
    public let tetherLength = Variable<Scalar>(10)
    public let turningRadius = Variable<Scalar>(3)
    
    // Wind
    public let wind = Variable<Vector>(e_x)
    
    // MARK: Intermediate Variables
    
    // Rx
    private let theta = Variable<Scalar>(0)
    private let d = Variable<Scalar>(0)
    
    // Normal
    private var c: Vector = .origin
    private var e_πz: Vector = e_z
    private var e_πy: Vector = e_y
    private var e_kite: Vector = e_y
    
    private var pos: Vector = .origin
    private var att: Vector = .origin
    private var vel: Vector = .origin
    
    // MARK: Ouput Variables
    
    // KiteDataProvider
    
    public let position = PublishSubject<Vector>()
    public let attitude = PublishSubject<Matrix>()
    public let velocity = PublishSubject<Vector>()
    
    // KiteDataAnalyser
    
    public let tetherPoint = PublishSubject<Vector>()
    public let turningPoint = PublishSubject<Vector>()

//    public let estimatedWind = PublishSubject<Vector?>()
//    public let tetherPoint = PublishSubject<Vector?>()
//    public let turningPoint = PublishSubject<Vector?>()
//    public let turningRadius = PublishSubject<Scalar?>()
//    public let isTethered = PublishSubject<Scalar>()
    
    // MARK: Ouput Variables

    public init() {
        // Emulator Input
        Observable.combineLatest(tetherLength.asObservable(), turningRadius.asObservable(), resultSelector: getD)
            .bindTo(d)
            .disposed(by: bag)

        gamma.asObservable()
            .map(getTheta)
            .bindTo(theta)
            .disposed(by: bag)
        

//        Observable.combineLatest(theta.asObservable(), phi.asObservable(), d.asObservable(), phaseSpeed.asObservable(), resultSelector: noOp)
//            .filter { _ in self.paused }
//            .subscribe(onNext: update)
//            .disposed(by: bag)
        
//        forcedPhase.asObservable()
//            .filter { _ in self.paused }
//            .subscribe(onNext: update)
//            .disposed(by: bag)
        
        // AnalyserType Output
//        r.asObservable()
//            .bindTo(turningRadius)
//            .disposed(by: bag)
    }
    
//    private func update(phase: Scalar) {
//        print("Phase: \(phase)")
//        update(theta: theta.value, phi: phi.value, d: d.value, omega: 1)
//    }

    public func update(elapsed: TimeInterval) {
        if elapsed >= 1/updateFrequency {
            update(elapsed: elapsed)
        }
    }

//    private func update(elapsed: TimeInterval) {
//        let omega = phaseSpeed.value
//        phase += omega*Scalar(elapsed)*0.2
//        update(theta: theta.value, phi: phi.value, d: d.value, omega: omega)
//    }
    
    private func update(theta: Scalar, phi: Scalar, d: Scalar, omega: Scalar) {
        
        //        if (w - v).norm == 0 { return }
        //        if p.norm == 0 { return }
        //
        //        let apparent = w - v
        //        let e_p = p.unit
        //
        //        if apparent.norm == 0 { return }
        //
        //        // Kite
        //
        //        let sx = -apparent.unit
        //        let sy = -sx×e_p
        //        let sz = sx×sy
        //        
        //        let rotation = Matrix(vx: sx, vy: sy, vz: sz)

        let m_phi = Matrix(rotation: .ez, by: phi)
        let m_theta = Matrix(rotation: .ey, by: theta)
        let m = m_theta*m_phi
        
        c = d*(e_z*m)
        
        e_πz = -e_x*m
        e_πy = e_y*m
        e_kite = e_πy.rotated(around: c, by: phase)
        
        pos = c + r.value*e_kite
        vel = omega*c.unit×e_kite
        
        if vel.norm > 0 {
            att = Vector(0, 0, vel.angle(to: e_x))
        }
        
        position.onNext(pos)
        velocity.onNext(vel)
        attitude.onNext(att)
        
        tetherPoint.onNext(.origin)
        turningPoint.onNext(c)
        
    }
    
    // Helper Methods - Pure
    
    private func getD(l: Scalar, r: Scalar) -> Scalar {
        return sqrt(l*l - r*r)
    }
    
    private func getTheta(gamma: Scalar) -> Scalar {
        return  π/2 - gamma
    }
    
}

//        print("GetWind; r: \(r), phi: \(phi) -> \(r*Vector.ex.rotated(around: .ez, by: phi))")


