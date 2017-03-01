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
    private let bag = DisposeBag()
    
    // MARK: Input Variables
    
    public let gamma = Variable<Scalar>(0)
    public let phi = Variable<Scalar>(0)
    
    public let l = Variable<Scalar>(10)
    public let r = Variable<Scalar>(3)
    
    public let phase = Variable<Scalar>(0)
    public let phiWind = Variable<Scalar>(0)
    
    // MARK: Intermediate Variables
    
    // Computed
    
    private let theta = Variable<Scalar>(0)
    private let d = Variable<Scalar>(0)
    
    // Stored
    
    private var c = Vector()
    private var e_πz = Vector()
    private var e_πy = Vector()
    
    private var pos = Vector(0, 0, 0)
    private var att = Vector(0, 0, 0)
    
    // Debug
    
    //    public var debug_c: Vector { return c }
    //    public var debug_e_πz: Vector { return e_πz }
    //    public var debug_e_πy: Vector { return e_πy }
    
    // MARK: Ouput Variables
    
    // KiteDataProvider
    
    public let position = PublishSubject<Vector>()
    public let attitude = PublishSubject<Vector>()
    
    // KiteDataAnalyser
    
    public let tetherPoint = PublishSubject<Vector?>()
    public let turningPoint = PublishSubject<Vector?>()
    public let turningRadius = PublishSubject<Scalar?>()
    public let isTethered = PublishSubject<Scalar>()
    
    public init() {
        Observable.combineLatest(l.asObservable(), r.asObservable(), resultSelector: getD)
            .bindTo(d)
            .disposed(by: bag)
        
        gamma.asObservable()
            .map(getTheta)
            .bindTo(theta)
            .disposed(by: bag)
    
        Observable.combineLatest(theta.asObservable(), phi.asObservable(), d.asObservable(), phase.asObservable(), resultSelector: noOp)
            .subscribe(onNext: update)
            .disposed(by: bag)
        
        r.asObservable()
            .bindTo(turningRadius)
            .disposed(by: bag)
    }
    
    public func update(theta: Scalar, phi: Scalar, d: Scalar, phase: Scalar) {
        let m_phi = Matrix(rotation: .ez, by: phi)
        let m_theta = Matrix(rotation: .ey, by: theta)
        
        c = (d*Vector.ez).transformed(by: m_theta).transformed(by: m_phi)
        
        e_πz = (-Vector.ex).transformed(by: m_theta).transformed(by: m_phi)
        e_πy = Vector.ey.transformed(by: m_theta).transformed(by: m_phi)
        
        pos = c + r.value*e_πy.rotated(around: c, by: phase)
        att = Vector(0, phase, 0)
        
        position.onNext(pos)
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
}
