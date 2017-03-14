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

class KiteAnalyzer {
    // Inputs
    
    public let position = Variable<Vector>(.origin)
    public let velocity = Variable<Vector>(.origin)
    public let attitude = Variable<Matrix>(.id)
    
    // Outputs
    
    public let positionOut = PublishSubject<Vector>()
    public let velocityOut = PublishSubject<Vector>()
    public let attitudeOut = PublishSubject<Matrix>()

    // Internal

    private let bag = DisposeBag()
    
    private let realm = try! Realm()
    
    private var data: KiteData?
    
    init() {
    }
    
    public func start() {
        try! realm.write {
            let kiteData = KiteData()
            realm.add(kiteData)
            data = kiteData
        }
    }
    
    
}
