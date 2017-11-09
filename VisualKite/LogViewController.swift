//
//  LogViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-07-28.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import RxSwift

struct TimedAccelerations: Timed {
    let time: TimeInterval
    let acc: Vector
}

struct TimedActuatorValues: Timed {
    let time: TimeInterval
    let values: [Float]
}

struct TimedPursuitLog: Timed {
    let time: TimeInterval
    let rollRate: Float
    let arcRadius: Float

    let pos: CGPoint
    let vel: CGPoint
    let target: CGPoint
}

struct LogModel {
    public var start: TimeInterval { return min(orientations.first?.time ?? 0, locations.first?.time ?? 0) }
    public var end: TimeInterval { return max(orientations.last?.time ?? 1, locations.last?.time ?? 1) }
    public var duration: Double { return end - start }

    public var isEmpty: Bool { return locations.isEmpty || orientations.isEmpty }

    public let url: URL

    public let tetherLength: Float
    public let posB: Vector
    public let phiC: Float
    public let thetaC: Float
    public let turningRadius: Float

    public let locations: [TimedLocation]
    public let orientations: [TimedOrientation]
    public let actuators: [TimedActuatorValues]
    public let pursuits: [TimedPursuitLog]
    public let accelerations: [TimedAccelerations]

    public func configuration(for time: TimeInterval) -> TimedConfiguration {
        return (location(at: time).val, orientation(at: time).val)
    }

    public func absolute(_ rel: Scalar) -> TimeInterval {
        return start + duration*Double(rel)
    }

    public func location(at time: TimeInterval) -> (index: Int, val: TimedLocation) { return value(at: time, among: locations) }
    public func orientation(at time: TimeInterval) -> (index: Int, val: TimedOrientation) { return value(at: time, among: orientations) }
    public func actuator(at time: TimeInterval) -> (index: Int, val: TimedActuatorValues) { return value(at: time, among: actuators) }
    public func pursuit(at time: TimeInterval) -> (index: Int, val: TimedPursuitLog) { return value(at: time, among: pursuits) }
    public func accelerations(at time: TimeInterval) -> (index: Int, val: TimedAccelerations) { return value(at: time, among: accelerations) }

    public func value<T: Timed>(at time: TimeInterval, among timedValues: [T]) -> (Int, T) {
        let index = timedValues.enumerated().max { abs($1.element.time - time) < abs($0.element.time - time) }?.offset ?? 0
        return (index, timedValues[index])
    }
}

typealias TimedConfiguration = (loc: TimedLocation, ori: TimedOrientation)

typealias ArcData = (radius: Scalar, center: Vector, angle2: Scalar, radius2: Scalar, center2: Vector, target: Vector, c: Vector)

struct LogProcessor {
    enum Change { case scrubbed, scrubbedByVideo, changedRange, reset }

    enum RequestedTime {
        case relRel(t: Scalar)
        case video(t: TimeInterval)
    }

    public var requestedTime: RequestedTime = .relRel(t: 0) { didSet { update(all: false) } }
    public var videoTime: TimeInterval = 0

    public let change = PublishSubject<Change>()

    public static var shared = LogProcessor()

    public var t0Rel: Scalar = 0 { didSet { update() } }
    public var t1Rel: Scalar = 1 { didSet { update() } }
    public var stepCount: Int = 1 { didSet { update() } }

    // Path

    public var pathLocations: [TimedLocation] = []

    // Scrubbing

    private var time: TimeInterval = 0
    public var videoTimeOffset: TimeInterval = 0 { didSet { update(all: false) } }
    public var timeSinceStart: TimeInterval { return time - (model?.start ?? 0) }
    public var steppedConfigurations: [TimedConfiguration] = []

    // Pursuit

    public var arcData: ArcData?

    // Model

    public var model: LogModel?

    // Private variables

    // API

    public mutating func load(_ newModel: LogModel) {
        model = newModel
        update()
        change.onNext(.reset)
    }

    public mutating func clear() {
        model = nil
        update()
        change.onNext(.reset)
    }

    public var logText: String {
        guard let model = model, !model.isEmpty else {
            return "Log not loaded"
        }

        let actText, pursuitText, accelerationsText: String

        if model.actuators.count > 0 {
            actText = model.actuator(at: time).val.values[0..<2].enumerated().map { " \($0): \($1)" }.joined(separator: "\n")
        }
        else {
            actText = " N/A"
        }

        if model.pursuits.count > 0 {
            let p = model.pursuit(at: time).val
            pursuitText = String(format:" arc radius: %.2f\n rollrate: %.2f\n target: (%.1f, %.1f)\n speed: %.1f m/s", p.arcRadius, p.rollRate, p.target.x, p.target.y, p.vel.r)
        }
        else {
            pursuitText = " N/A"
        }

        if model.accelerations.count > 0 {
            let a = model.accelerations(at: time).val
            accelerationsText = String(format:" vector: (%.1f, %.1f, %.1f)\n magnitude: %.2f", a.acc.x, a.acc.y, a.acc.z, a.acc.norm)
        }
        else {
            accelerationsText = " N/A"
        }

        return String(format: "Time: %.2f\n", time) + "\nactuator_output:\n" + actText + "\nlogged:\n" + pursuitText + "\nacceleration:\n" + accelerationsText
    }

    // Helper methods

    private mutating func update(all updateAll: Bool = true) {
        guard let model = model else {
            return
        }

        let drivenByVideo: Bool
        switch requestedTime {
        case .relRel(t: let t):
            time = model.absolute(t0Rel*(1 - t) + t1Rel*t)
            videoTime = time - model.start - videoTimeOffset
            drivenByVideo = false
        case .video(t: let t):
            time = model.start + min(max(t + videoTimeOffset, 0), model.duration)
            videoTime = t
            drivenByVideo = true
        }

        if updateAll {
            updatePath(with: model)
        }

        updateStepped(with: model, drivenByVideo: drivenByVideo)
    }

    private mutating func updatePath(with model: LogModel) {
        guard !model.isEmpty else {
            pathLocations = []
            return
        }

        pathLocations = Array(model.locations[model.location(at: model.absolute(t0Rel)).index..<model.location(at: model.absolute(t1Rel)).index])
        change.onNext(.changedRange)
    }

    private mutating func updateStepped(with model: LogModel, drivenByVideo: Bool) {
        steppedConfigurations = []
        arcData = nil

        guard !model.isEmpty else {
            time = 0
            return
        }

        let startTime = model.absolute(t0Rel)
        let timeSinceStart = time - startTime
        let visibleDuration = model.duration*Double(t1Rel - t0Rel) + 0.0001
        let timeStep = visibleDuration/Double(stepCount)

        steppedConfigurations = (0..<stepCount)
            .map { i in (timeSinceStart + Double(i)*timeStep).truncatingRemainder(dividingBy: visibleDuration) + startTime }
            .map(model.configuration)

        // Target related

        let c = getC(phi: CGFloat(model.phiC), theta: CGFloat(model.thetaC), d: getD(tether: CGFloat(model.tetherLength), r: CGFloat(model.turningRadius)))

        if c.norm > 0 && model.pursuits.count > 0 {
            let p = model.pursuit(at: time).val

            let piPlane = Plane(center: c, normal: c.unit)
            let target = piPlane.deCollapse(point: p.target)

            if let loc = steppedConfigurations.first?.loc, loc.vel.norm > 0 {
                let radius = p.arcRadius.isNaN ? 1000 : Scalar(p.arcRadius)
                let center = loc.pos - radius*(piPlane.normal×loc.vel).unit
                print("==================")
                print("   p: \(p)")
                print("   loc.pos: \(loc.pos)")
                print("   radius: \(radius)")
                print("   piPlane.normal: \(piPlane.normal)")
                print("   loc.vel: \(loc.vel)")
                print("   piPlane.normal×loc.vel: \(piPlane.normal×loc.vel)")
                print("   center: \(center)")

                let (arcAngle2, center2point, radius2) = Pursuit.angleCenterRadius(position: p.pos, target: p.target, attitude: p.vel.norm > 0 ? p.vel.unit : CGPoint(x: 1, y: 0))
                let center2 = piPlane.deCollapse(point: center2point)

                arcData = (radius, center, arcAngle2, radius2, center2, target, c)
            }
        }

        change.onNext(drivenByVideo ? .scrubbedByVideo : .scrubbed)
    }
}

class LogViewController: NSViewController {
    @IBOutlet weak var tSlider: NSSlider!
    @IBOutlet weak var t0Slider: NSSlider!
    @IBOutlet weak var t1Slider: NSSlider!
    @IBOutlet weak var stepSlider: NSSlider!

    @IBOutlet weak var videoOffsetField: NSTextField!
    @IBOutlet weak var videoOffsetSlider: NSSlider!

    @IBOutlet weak var loadButton: NSButton!

    private let bag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        tSlider.scalar.bind { LogProcessor.shared.requestedTime = .relRel(t: $0) }.disposed(by: bag)
        t0Slider.scalar.bind { LogProcessor.shared.t0Rel = $0 }.disposed(by: bag)
        t1Slider.scalar.bind { LogProcessor.shared.t1Rel = $0 }.disposed(by: bag)

        stepSlider.scalar.map { Int(round($0*$0)) }.bind { LogProcessor.shared.stepCount = $0 }.disposed(by: bag)

        loadButton.rx.tap.bind(onNext: tappedLoadButton).disposed(by: bag)

        Observable.combineLatest(videoOffsetField.rx.text, videoOffsetSlider.scalar).bind { _ in self.offsetChanged() }.disposed(by: bag)
    }

    private func offsetChanged() {
        LogProcessor.shared.videoTimeOffset = videoOffsetField.doubleValue + videoOffsetSlider.doubleValue
    }

    private func tappedLoadButton() {
        guard LogProcessor.shared.model?.isEmpty ?? true else {
            LogProcessor.shared.clear()
            loadButton.title = "Load"
            return
        }

        let panel = NSOpenPanel()
        panel.begin { result in
            if result.rawValue == NSFileHandlingPanelOKButton {
                self.load(panel.urls[0])
            }
        }

        loadButton.title = "Clear"
    }

    private func load(_ url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            fatalError("failed to load data")
        }

        guard let parser = ULogParser(data) else {
            fatalError("failed to parse data")
        }

        let tetherLength = parser.floatParameter("MPC_TETHER_LEN")
        let posB = parser.vectorParameter("MPC_X_POS_B", "MPC_Y_POS_B", "MPC_Z_POS_B")
        let phiC = parser.floatParameter("MPC_PHI_C")
        let thetaC = parser.floatParameter("MPC_THETA_C")
        let turningRadius = parser.floatParameter("MPC_LOOP_TURN_R")

        let locations: [TimedLocation] = parser.read("vehicle_local_position") { TimedLocation(time: $0.timestamp, pos: $0.vector("x", "y", "z") - posB, vel: $0.vector("vx", "vy", "vz")) }

        let orientations: [TimedOrientation] = parser.read("vehicle_attitude") { TimedOrientation(time: $0.timestamp, orientation: $0.quaternion("q"), rate: .zero) }

        let actuators: [TimedActuatorValues] = parser.read("actuator_controls_1") { TimedActuatorValues(time: $0.timestamp, values: $0.values("control")) }

        let pursuits: [TimedPursuitLog] = parser.read("fw_turning") {
            TimedPursuitLog(time: $0.timestamp, rollRate: $0.value("roll_rate"), arcRadius: $0.value("arc_radius"), pos: CGPoint(x: $0.float("x"), y: $0.float("y")), vel: CGPoint(x: $0.float("vx"), y: $0.float("vy")), target: CGPoint(x: $0.float("tx"), y: $0.float("ty")))
        }

        let accelerations: [TimedAccelerations] = parser.read("sensor_combined") {
            let acc = $0.floats("accelerometer_m_s2")
            return TimedAccelerations(time: $0.timestamp, acc: Vector(acc[0], acc[1], acc[2]))
        }

        let model = LogModel(url: url, tetherLength: tetherLength, posB: posB, phiC: phiC, thetaC: thetaC, turningRadius: turningRadius, locations: locations, orientations: orientations, actuators: actuators, pursuits: pursuits, accelerations: accelerations)
        LogProcessor.shared.load(model)
    }
}

extension ULogReader {
    public func vector(_ pathX: String, _ pathY: String, _ pathZ: String) -> Vector {
        return Vector(float(pathX), float(pathY), float(pathZ))
    }

    public func quaternion(_ path: String) -> Quaternion {
        let q = floats(path)
        return Quaternion(q[1], q[2], q[3], q[0])
    }
}

extension ULogParser {
    public func vectorParameter(_ nameX: String, _ nameY: String, _ nameZ: String) -> Vector {
        return Vector(floatParameter(nameX), floatParameter(nameY), floatParameter(nameZ))
    }
}

