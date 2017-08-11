//
//  LogViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-07-28.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import RxSwift

struct LogModel {
    public let start: TimeInterval
    public let end: TimeInterval
    public let locations: [TimedLocation]
    public let orientations: [TimedOrientation]

    public var isEmpty: Bool { return locations.isEmpty }

    init(locations: [TimedLocation], orientations: [TimedOrientation]) {
        self.locations = locations
        self.orientations = orientations
        self.start = min(orientations.first?.time ?? 0, locations.first?.time ?? 0)
        self.end = max(orientations.last?.time ?? 1, locations.last?.time ?? 1)
    }

    public static let empty = LogModel(locations: [], orientations: [])

    public static let test: LogModel = {
        let duration = 10.0
        let n = 1000
        let tetherLength: Scalar = 100
        let indices = 0..<n
        let turns = 3
        let phiC: Scalar = π/3
        let thetaC: Scalar = π/4

        let r: Scalar = 20
        let d = sqrt(tetherLength*tetherLength - r*r)
        let c = Vector(phi: phiC, theta: π/2 + thetaC, r: d)

        let ePiX = (c.unit×e_z).unit
        let ePiY = ePiX×c.unit

        let speed: Scalar = 10

        let locations: [TimedLocation] = indices.map { i in
            let rho = Scalar(i)/Scalar(n - 1)
            let gamma = 2*π*Scalar(turns)*rho

            let time = duration*Double(rho)

            let pos = c + r*(ePiX*sin(gamma) + ePiY*cos(gamma))
            let deltaPos = (r/50)*Vector(cos(17*gamma), cos(19*gamma), cos(23*gamma))

            let vel = speed*(ePiX*cos(gamma) - ePiY*sin(gamma))
            let deltaVel = (speed/50)*Vector(cos(29*gamma), cos(37*gamma), cos(41*gamma))

            return TimedLocation(time: time, pos: pos + deltaPos, vel: vel + deltaVel)
        }

        let orientations: [TimedOrientation] = locations.map { location in
            return TimedOrientation(time: location.time, orientation: Quaternion(rotationFrom: e_z, to: location.vel), rate: .zero)
        }

        return LogModel(locations: locations, orientations: orientations)
    }()
}

typealias TimedConfiguration = (loc: TimedLocation, ori: TimedOrientation)

struct LogProcessor {
    enum Change { case scrubbed, changedRange }

    public let change = PublishSubject<Change>()

    public static var shared = LogProcessor()

    public var start: Double { return model.start }
    public var end: Double { return model.end }
    public var duration: Double { return model.end - model.start }

    public var tRelRel: Scalar = 0 { didSet { updateCurrent() } }
    public var t0Rel: Scalar = 0 { didSet { updateVisible() } }
    public var t1Rel: Scalar = 1 { didSet { updateVisible() } }
    public var step: Scalar = 10 { didSet { updateVisible() } }

    // Current
    public var time: Double = 0
    public var currentConfiguration: TimedConfiguration = (TimedLocation(), TimedOrientation())

    // Visible
    public var pathLocations: [TimedLocation] = []
    public var steppedConfigurations: [TimedConfiguration] = []

    private var model: LogModel = .test

    public mutating func load(_ newModel: LogModel) {
        model = newModel
        updateCurrent()
        updateVisible()
    }

    // Helper methods

    public mutating func clear() {
        model = .empty
        updateCurrent()
        updateVisible()
    }

    private mutating func updateCurrent() {
        guard !model.isEmpty else {
            time = 0
            currentConfiguration = (TimedLocation(), TimedOrientation())
            return
        }

        let tRel = t0Rel*(1 - tRelRel) + t1Rel*tRelRel
        time = absolute(tRel)

        guard let config = configuration(for: time) else {
            return
        }

        currentConfiguration = config
        change.onNext(.scrubbed)
    }

    private func configuration(for time: TimeInterval) -> TimedConfiguration? {
        guard let iLoc = locationIndex(for: time), let iOri = orientationIndex(for: time) else {
            return nil
        }

        return (model.locations[iLoc], model.orientations[iOri])
    }

    private mutating func updateVisible() {
        steppedConfigurations = []

        guard !model.isEmpty else {
            pathLocations = []
            return
        }

        let startTime = absolute(t0Rel)
        let endTime = absolute(t1Rel)

        // Position path
        guard let fromLocIndex = locationIndex(for: startTime), let toLocIndex = locationIndex(for: endTime) else {
            return
        }

        pathLocations = Array(model.locations[fromLocIndex...toLocIndex])

        guard let fromOriIndex = orientationIndex(for: startTime), let toOriIndex = orientationIndex(for: endTime) else {
            return
        }


        var locIndex = fromLocIndex
        var oriIndex = fromOriIndex

//        while locationIndex < toLocationIndex, orientationIndex < toOrientationoIndex   {
////            let orientation = orien
//
//        }


            //        let visibleLocations = strodeRange.map { model.locations[$0] }


//        let strodeRange = stride(from: index(for: t0Rel), to: index(for: t1Rel), by: step)
//        let visibleLocations = strodeRange.map { model.locations[$0] }
//        strodePositions = visibleLocations.map(TimedLocation.getPosition)
//        velocities = visibleLocations.map(TimedLocation.getVelocity)
//        orientations = strodeRange.map { model.orientations[$0].orientation }
        change.onNext(.changedRange)
    }

    private func absolute(_ rel: Scalar) -> TimeInterval {
        return start + duration*Double(rel)
    }

    private func locationIndex(for time: TimeInterval) -> Int? {
        return model.locations.index { $0.time >= time }
    }

    private func orientationIndex(for time: TimeInterval) -> Int? {
        return model.orientations.index { $0.time >= time }
    }
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

        tRelRel.bind { LogProcessor.shared.tRelRel = $0 }.disposed(by: bag)
        t0Rel.bind { LogProcessor.shared.t0Rel = $0 }.disposed(by: bag)
        t1Rel.bind { LogProcessor.shared.t1Rel = $0 }.disposed(by: bag)

        Observable.combineLatest(tRelRel, t0Rel, t1Rel).bind { _ in
            let p = LogProcessor.shared.currentConfiguration.loc.pos
            self.currentPositionLabel.stringValue = String(format: "NED: %.1f, %.1f, %.1f", p.x, p.y, p.z)
            self.tLabel.stringValue = String(format: "%.2f", LogProcessor.shared.time)
            }
            .disposed(by: bag)

        let step = stepSlider.scalar.shareReplayLatestWhileConnected()
        step.map { String(format: "%.1f", $0) }.bind(to: stepLabel.rx.text).disposed(by: bag)
        step.bind { LogProcessor.shared.step = $0 }.disposed(by: bag)

        loadButton.rx.tap.bind { self.load("~/Dropbox/10. KITEX/PrototypeDesign/10_32_17.ulg") }.disposed(by: bag)
        clearButton.rx.tap.bind { LogProcessor.shared.clear() }.disposed(by: bag)
    }

    private func load(_ path: String) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)) else {
            fatalError("failed to load data")
        }

        guard let parser = ULogParser(data) else {
            fatalError("failed to parse data")
        }

        let locations: [TimedLocation] = parser.read("vehicle_local_position") { read in
            let time = Double(read.value("timestamp") as UInt64)/1000000
            let pos = Vector(read.value("x") as Float, read.value("y") as Float, read.value("z") as Float)
            let vel = Vector(read.value("vx") as Float, read.value("vy") as Float, read.value("vz") as Float)

            return TimedLocation(time: time, pos: pos, vel: vel)
        }

        let orientations: [TimedOrientation] = parser.read("vehicle_attitude") { read in
            let time = Double(read.value("timestamp") as UInt64)/1000000

            let qs: [Float] = read.values("q")
            let orientation = Quaternion(qs[1], qs[2], qs[3], qs[0])

            return TimedOrientation(time: time, orientation: orientation, rate: .zero)
        }

        let model = LogModel(locations: locations, orientations: orientations)

        LogProcessor.shared.load(model)
    }
}




