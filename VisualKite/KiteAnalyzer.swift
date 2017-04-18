//
//  KiteAnalyzer.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-10.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import Foundation
import RealmSwift
import RxSwift
import RxCocoa

public struct Estimate<T> {
    let value: T
    let certainty: Double
}

class KiteAnalyzer {
    // Inputs
    
    public let location = Variable<KiteLocation>(KiteLocation())
    public let attitude = Variable<KiteAttitude>(KiteAttitude())
    public let tetherLength = Variable<Scalar>(100)
    
//    public let position = Variable<Vector>(.origin)
//    public let velocity = Variable<Vector>(.origin)
//    public let attitude = Variable<Matrix>(.id)
    
    // Outputs
    
    public let estimatedB = PublishSubject<Estimate<Vector>>()

//    public let positionOut = PublishSubject<Vector>()
//    public let velocityOut = PublishSubject<Vector>()
//    public let attitudeOut = PublishSubject<Matrix>()

    // Internal

    private let bag = DisposeBag()
    
    private let realm = try! Realm()

    private var data: KiteData?

    private var locations = [KiteLocation]()
    
    init() {
//        location.asObservable().bindNext(receivedLocation).disposed(by: bag)
    }
    
    public func start() {
        try! realm.write {
            let kiteData = KiteData()
            realm.add(kiteData)
            data = kiteData
        }
    }
    
    private func error(with sphere: Sphere, points: [Vector]) -> Scalar {
        var rSquared: Scalar = 0
        
        for point in points {
            rSquared += point.distance(to: sphere)
        }
        
        return rSquared
    }
    
}





