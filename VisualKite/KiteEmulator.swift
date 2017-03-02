//
//  KiteEmulator.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-02-28.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import Foundation
import RxSwift

func noOp<T>(value: T) -> T { return value }

final class KiteEmulator: KiteType, AnalyserType {
    private let updateFrequency: Double = 10
    private var lastUpdate: TimeInterval = 0
    
    private let bag = DisposeBag()
    
    // MARK: Input Variables
    
    // Meta
    public let phaseSpeed = Variable<Scalar>(0)

    // Kite
    public let gamma = Variable<Scalar>(0)
    public let phi = Variable<Scalar>(0)
    
    public let l = Variable<Scalar>(10)
    public let r = Variable<Scalar>(3)
    
    // Wind
    public let phiWind = Variable<Scalar>(0)
    public let rWind = Variable<Scalar>(0.6)
    
    // MARK: Intermediate Variables
    
    // Rx
    private let theta = Variable<Scalar>(0)
    private let d = Variable<Scalar>(0)
    
    // Normal
    private var phase: Scalar = 0
    private var c: Vector = .origin
    private var e_πz: Vector = .ez
    private var e_πy: Vector = .ey
    private var e_kite: Vector = .ey
    
    private var pos: Vector = .origin
    private var att: Vector = .origin
    private var vel: Vector = .origin
    
    // MARK: Ouput Variables
    
    // KiteDataProvider
    
    public let position = PublishSubject<Vector>()
    public let velocity = PublishSubject<Vector>()
    public let attitude = PublishSubject<Vector>()
    
    // KiteDataAnalyser
    
    public let estimatedWind = PublishSubject<Vector?>()
    public let tetherPoint = PublishSubject<Vector?>()
    public let turningPoint = PublishSubject<Vector?>()
    public let turningRadius = PublishSubject<Scalar?>()
    public let isTethered = PublishSubject<Scalar>()
    
    // wind
    
    public let wind = PublishSubject<Vector>()

    // MARK: Ouput Variables

    public init() {
        // Emulator Input
        Observable.combineLatest(l.asObservable(), r.asObservable(), resultSelector: getD)
            .bindTo(d)
            .disposed(by: bag)
        
        gamma.asObservable()
            .map(getTheta)
            .bindTo(theta)
            .disposed(by: bag)
        
        Observable.combineLatest(rWind.asObservable(), phiWind.asObservable(), resultSelector: getWind)
            .bindTo(wind)
            .disposed(by: bag)

        // AnalyserType Output
        r.asObservable()
            .bindTo(turningRadius)
            .disposed(by: bag)
    }
    
    public func update(time: TimeInterval) {
        let elapsed = time - lastUpdate
        if elapsed >= 1/updateFrequency {
            update(elapsed: elapsed)
            lastUpdate = time
        }
    }

    private func update(elapsed: TimeInterval) {
        let omega = phaseSpeed.value
        phase += omega*Scalar(elapsed)
        update(theta: theta.value, phi: phi.value, d: d.value, omega: omega)
    }
    
    private func update(theta: Scalar, phi: Scalar, d: Scalar, omega: Scalar) {
        let m_phi = Matrix(rotation: .ez, by: phi)
        let m_theta = Matrix(rotation: .ey, by: theta)
        let m = m_theta*m_phi
        
        c = d*(.ez*m)
        
        e_πz = -.ex*m
        e_πy = .ey*m
        e_kite = e_πy.rotated(around: c, by: phase)
        
        pos = c + r.value*e_kite
        vel = omega*c.unit×e_kite
        att = Vector(0, phase, 0)
        
        position.onNext(pos)
        velocity.onNext(vel)
        attitude.onNext(att)
        
        tetherPoint.onNext(.origin)
        turningPoint.onNext(c)
        
        isTethered.onNext(1)
    }
    
    // Helper Methods - Pure
    
    private func getD(l: Scalar, r: Scalar) -> Scalar {
        return sqrt(l*l - r*r)
    }
    
    private func getTheta(gamma: Scalar) -> Scalar {
        return  π/2 - gamma
    }
    
    private func getWind(r: Scalar, phi: Scalar) -> Vector {
//        print("GetWind; r: \(r), phi: \(phi) -> \(r*Vector.ex.rotated(around: .ez, by: phi))")
        return r*Vector.ex.rotated(around: .ez, by: phi)
    }
}
