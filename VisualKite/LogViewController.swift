//
//  LogViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-07-28.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import RxSwift

struct LogMNodel {
    public let duration: Double
    public let locations: [TimedLocation]
    public let orientations: [TimedOrientation]

    public var isEmpty: Bool { return locations.isEmpty }

    public static let empty = LogMNodel(duration: 1, locations: [], orientations: [])

    public static let test: LogMNodel = {
        let duration = 10.0
        let n = 1000
        let tetherLength: Scalar = 100
        let indices = 0..<n
        let turns = 1
        let phiC: Scalar = π/3
        let thetaC: Scalar = π/4

        let r: Scalar = 20
        let d = sqrt(tetherLength*tetherLength - r*r)
        let c = Vector(phi: phiC, theta: π/2 + thetaC, r: d)

        let ePiX = (c.unit×e_z).unit
        let ePiY = ePiX×c.unit

        let speed: Scalar = 10

        let alpha: Scalar = π/8

        let locations: [TimedLocation] = indices.map { i in
            let rho = Scalar(i)/Scalar(n - 1)
            let gamma = 2*π*Scalar(turns)*rho

            let time = duration*Double(rho)

            let pos = c + r*(ePiX*sin(gamma) + ePiY*cos(gamma))
            let deltaPos = 0*(r/10)*Vector(cos(17*gamma), cos(19*gamma), cos(23*gamma))

            let vel = speed*(ePiX*cos(gamma) - ePiY*sin(gamma))
            let deltaVel = 0*(speed/10)*Vector(cos(29*gamma), cos(37*gamma), cos(41*gamma))

            return TimedLocation(time: time, pos: pos + deltaPos, vel: vel + deltaVel)
        }

        let orientations: [TimedOrientation] = locations.map { location in
            let vel = location.vel
            let angle = vel.angle(to: e_z)
            let axis = Vector(vel.y, -vel.x, 0).unit
            let orientation = Quaternion(axis: axis, angle: angle)

            return TimedOrientation(time: location.time, orientation: orientation, rate: .zero)
        }

        return LogMNodel(duration: duration, locations: locations, orientations: orientations)
    }()
}

struct LogProcessor {
    public static var shared = LogProcessor()

    public var duration: Double { return model.duration }

    public var tRelRel: Scalar = 0 { didSet { updateCurrent() } }
    public var t0Rel: Scalar = 0 { didSet { updateVisible() } }
    public var t1Rel: Scalar = 1 { didSet { updateVisible() } }
    public var step = 10 { didSet { updateVisible() } }
    
    // Current
    public var time: Double = 0
    public var position: Vector = .origin
    public var velocity: Vector = .origin
    public var orientation: Quaternion = .id

    // Visible
    public var positions: [Vector] = []
    public var velocities: [Vector] = []
    public var orientations: [Quaternion] = []

//    public var angularVelocities: [Vector] = []

    private var model: LogMNodel = .test

    public mutating func load(_ newModel: LogMNodel) {
        model = newModel
        updateCurrent()
        updateVisible()
    }

    // Helper methods

    public mutating func clear() {
        model = .empty
        position = .zero
        velocity = .zero
        orientation = .id
        positions = []
        velocities = []
        orientations = []
    }

    private mutating func updateCurrent() {
        let tRel = t0Rel*(1 - tRelRel) + t1Rel*tRelRel
        time = duration*Double(tRel)
        let i = index(for: tRel)
        position = model.locations[i].pos
        velocity = model.locations[i].vel
        orientation = model.orientations[i].orientation

        print("Update Current: (\(t0Rel) \(t1Rel)) \(tRel) - > \(i) [\(model.locations.count)]")
    }

    private mutating func updateVisible() {
        let visibleRange = stride(from: index(for: t0Rel), to: index(for: t1Rel), by: step)
        let visibleLocations = visibleRange.map { model.locations[$0] }
        positions = visibleLocations.map(TimedLocation.getPosition)
        velocities = visibleLocations.map(TimedLocation.getVelocity)
        orientations = visibleRange.map { model.orientations[$0].orientation }
    }

    private func index(for rel: Scalar) -> Int {
        return Int(round(rel*Scalar(model.locations.count - 1)))
    }
}

class LogLoader {

}

class LogViewController: NSViewController {
    @IBOutlet weak var tSlider: NSSlider!
    @IBOutlet weak var t0Slider: NSSlider!
    @IBOutlet weak var t1Slider: NSSlider!
    @IBOutlet weak var stepSlider: NSSlider!

    @IBOutlet weak var tLabel: NSTextField!
    @IBOutlet weak var stepLabel: NSTextField!
    @IBOutlet weak var currentPositionLabel: NSTextField!

    @IBOutlet weak var loadButton: NSButton!
    @IBOutlet weak var clearButton: NSButton!

    private let bag = DisposeBag()

    private var tRelRel: Scalar = 0
    private var t0Rel: Scalar = 0
    private var t1Rel: Scalar = 1

    override func viewDidLoad() {
        super.viewDidLoad()

        let tRelRel = tSlider.scalar.shareReplayLatestWhileConnected()
        let t0Rel = t0Slider.scalar.shareReplayLatestWhileConnected()
        let t1Rel = t1Slider.scalar.shareReplayLatestWhileConnected()

//        tRelRel.bind { LogProcessor.shared.tRelRel = $0 }.disposed(by: bag)
        t0Rel.bind { LogProcessor.shared.t0Rel = $0 }.disposed(by: bag)
        t1Rel.bind { LogProcessor.shared.t1Rel = $0 }.disposed(by: bag)

        let allTsCombined = Observable.combineLatest(tRelRel, t0Rel, t1Rel)

        allTsCombined
            .map(getT)
            .map(getDoubleString)
            .bind(to: tLabel.rx.text)
            .disposed(by: bag)

        allTsCombined.bind { _ in
            let p = LogProcessor.shared.position
            self.currentPositionLabel.stringValue = String(format: "NED: %.1f, %.1f, %.1f", p.x, p.y, p.z)
            }
            .disposed(by: bag)

        let step = stepSlider.scalar.map { Int(round($0)) }.shareReplayLatestWhileConnected()
        step.map(String.init).bind(to: stepLabel.rx.text).disposed(by: bag)
        step.bind { LogProcessor.shared.step = $0 }.disposed(by: bag)

        loadButton.rx.tap.bind { LogProcessor.shared.load(.test) }.disposed(by: bag)
        clearButton.rx.tap.bind { LogProcessor.shared.clear() }.disposed(by: bag)
    }

    private func getScalarString(scalar: Scalar) -> String {
        return String(format: "%.2f", scalar)
    }

    private func getDoubleString(double: Double) -> String {
        return String(format: "%.2f", double)
    }

    private func getT(tRelRel: Scalar, t0Rel: Scalar, t1Rel: Scalar) -> Double {
        return Double(t0Rel*(1 - tRelRel) + t1Rel*tRelRel)*LogProcessor.shared.duration
    }
}




