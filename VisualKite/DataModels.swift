//
//  DataModels.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-10.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import Foundation
import RealmSwift

class RealmVector: Object {
    dynamic var x = 0.0
    dynamic var y = 0.0
    dynamic var z = 0.0

    convenience init(_ vector: Vector) {
        self.init()
        x = Double(vector.x)
        y = Double(vector.y)
        z = Double(vector.z)
    }
    
    var vec: Vector { return Vector(x, y, z) }
}

class KiteOrientation: Object {
    dynamic var timeStamp: TimeInterval = 0

    dynamic var position: RealmVector?
    dynamic var velocity: RealmVector?
    dynamic var attitude: RealmVector?

    dynamic var isInterpolated = false

    var pos: Vector? { return position?.vec }
    var vel: Vector? { return velocity?.vec }
    var att: Vector? { return attitude?.vec }
    
    convenience init(_ timeStamp: TimeInterval, position: Vector) {
        self.init()
        self.timeStamp = timeStamp
        self.position = RealmVector(position)
    }
    
    convenience init(_ timeStamp: TimeInterval, velocity: Vector) {
        self.init()
        self.timeStamp = timeStamp
        self.velocity = RealmVector(velocity)
    }

    convenience init(_ timeStamp: TimeInterval, attitude: Vector) {
        self.init()
        self.timeStamp = timeStamp
        self.attitude = RealmVector(attitude)
    }
    
    convenience init(_ timeStamp: TimeInterval, velocity: Vector, position: Vector, attitude: Vector) {
        self.init()
        self.timeStamp = timeStamp
        self.position = RealmVector(position)
        self.velocity = RealmVector(velocity)
        self.attitude = RealmVector(attitude)
        self.isInterpolated = true
    }
}

class KiteData: Object {
    dynamic var sessionDescription: String = ""
    dynamic var uuid = UUID().uuidString
    
    let dataPoints = List<KiteOrientation>()
    
    var actual: Results<KiteOrientation> {
        return dataPoints.filter("isInterpolated == FALSE")
    }
}

//// Dog model
//class Dog: Object {
//    dynamic var name = ""
//    dynamic var owner: Person? // Properties can be optional
//}
//
//// Person model
//class Person: Object {
//    dynamic var name = ""
//    dynamic var birthdate = NSDate(timeIntervalSince1970: 1)
//    let dogs = List<Dog>()
//}
