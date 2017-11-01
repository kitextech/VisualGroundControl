//
//  LogViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-07-28.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import RxSwift

struct TimedActuatorValues: Timed {
    let time: TimeInterval
    let values: [Float]
}

struct TimedValue: Timed {
    let time: TimeInterval
    let value: Float
}

struct TimedPursuitLog: Timed {
    let time: TimeInterval
    let rollRate: Float32
    let arcRadius: Float32

    let posX: Float32
    let posY: Float32

    let velX: Float32
    let velY: Float32

    let targetX: Float32
    let targetY: Float32

    var pos: CGPoint {
        return CGPoint(x: CGFloat(posX), y: CGFloat(posY))
    }

    var vel: CGPoint {
        return CGPoint(x: CGFloat(velX), y: CGFloat(velY))
    }

    var target: CGPoint {
        return CGPoint(x: CGFloat(targetX), y: CGFloat(targetY))
    }
}

struct LogModel {
    public let start: TimeInterval
    public let end: TimeInterval
    public var duration: Double { return end - start }

    public let tetherLength: Float
    public let posB: Vector
    public let phiC: Float
    public let thetaC: Float
    public let turningRadius: Float

    public let locations: [TimedLocation]
    public let orientations: [TimedOrientation]
    public let actuators: [TimedActuatorValues]
    public let pursuits: [TimedPursuitLog]

    public var isEmpty: Bool { return locations.isEmpty || orientations.isEmpty }

    public static let empty = LogModel(tetherLength: 0, posB: .zero, phiC: 0, thetaC: 0, turningRadius: 0, locations: [], orientations: [], actuators: [], pursuits: [])

    init(tetherLength: Float, posB: Vector, phiC: Float, thetaC: Float, turningRadius: Float, locations: [TimedLocation], orientations: [TimedOrientation], actuators: [TimedActuatorValues], pursuits: [TimedPursuitLog]) {
        self.start = min(orientations.first?.time ?? 0, locations.first?.time ?? 0)
        self.end = max(orientations.last?.time ?? 1, locations.last?.time ?? 1)

        self.tetherLength = tetherLength
        self.posB = posB
        self.phiC = phiC
        self.thetaC = thetaC
        self.turningRadius = turningRadius

        self.locations = locations
        self.orientations = orientations
        self.actuators = actuators
        self.pursuits = pursuits
    }

    public func location(at time: TimeInterval) -> (index: Int, val: TimedLocation) { return value(at: time, among: locations) }
    public func orientation(at time: TimeInterval) -> (index: Int, val: TimedOrientation) { return value(at: time, among: orientations) }
    public func actuator(at time: TimeInterval) -> (index: Int, val: TimedActuatorValues) { return value(at: time, among: actuators) }
    public func pursuit(at time: TimeInterval) -> (index: Int, val: TimedPursuitLog) { return value(at: time, among: pursuits) }

    public func value<T: Timed>(at time: TimeInterval, among timedValues: [T]) -> (Int, T) {
        let index = timedValues.enumerated().max { abs($1.element.time - time) < abs($0.element.time - time) }?.offset ?? 0
        return (index, timedValues[index])
    }
}

typealias TimedConfiguration = (loc: TimedLocation, ori: TimedOrientation)

typealias ArcData = (radius: Scalar, center: Vector, angle2: Scalar, radius2: Scalar, center2: Vector, target: Vector, c: Vector)

struct LogProcessor {
    enum Change { case scrubbed, changedRange, reset }

    public let change = PublishSubject<Change>()

    public static var shared = LogProcessor()

    public var tRelRel: Scalar = 0 { didSet { updateStepped() } }
    public var t0Rel: Scalar = 0 { didSet { updateAll() } }
    public var t1Rel: Scalar = 1 { didSet { updateAll() } }
    public var stepCount: Int = 1 { didSet { updateAll() } }

    // Path

    public var pathLocations: [TimedLocation] = []

    // Stepped

    public var time: Double = 0
    public var timeSinceStart: Double { return time - model.start }
    public var steppedConfigurations: [TimedConfiguration] = []

    // Pursuit

    public var arcData: ArcData? = nil

    // Model

    public var model: LogModel = .empty

    // API

    public mutating func load(_ newModel: LogModel) {
        model = newModel
        updateAll()
        change.onNext(.reset)
    }

    public mutating func clear() {
        model = .empty
        updateAll()
        change.onNext(.reset)
    }

    public var logText: String {
        guard !model.isEmpty else {
            return "Log not loaded"
        }

        let actText, pursuitText: String

        if model.actuators.count > 0 {
            actText = model.actuator(at: time).val.values[0..<2].enumerated().map { " \($0): \($1)" }.joined(separator: "\n")
        }
        else {
            actText = " N/A"
        }

        if model.pursuits.count > 0 {
            let pursuit = model.pursuit(at: time).val
            pursuitText = " arc radius:\(pursuit.arcRadius)\n rollrate: \(pursuit.rollRate)\n target: \(pursuit.target)"
        }
        else {
            pursuitText = " N/A"
        }

        return String(format: "Time: %.2f\n", time) + "\nactuator_output:\n" + actText + "\nlogged:\n" + pursuitText
    }

    // Helper methods

    private mutating func updateAll() {
        updatePath()
        updateStepped()
    }

    private mutating func updatePath() {
        guard !model.isEmpty else {
            pathLocations = []
            return
        }

        pathLocations = Array(model.locations[model.location(at: absolute(t0Rel)).index..<model.location(at: absolute(t1Rel)).index])
        change.onNext(.changedRange)
    }

    private mutating func updateStepped() {
        steppedConfigurations = []
        arcData = nil

        guard !model.isEmpty else {
            time = 0
            return
        }

        let tRel = t0Rel*(1 - tRelRel) + t1Rel*tRelRel
        time = absolute(tRel)
        let startTime = absolute(t0Rel)
        let timeSinceStart = time - startTime
        let visibleDuration = model.duration*Double(t1Rel - t0Rel) + 0.0001
        let timeStep = visibleDuration/Double(stepCount)

        steppedConfigurations = (0..<stepCount)
            .map { i in (timeSinceStart + Double(i)*timeStep).truncatingRemainder(dividingBy: visibleDuration) + startTime }
            .map(configuration)

        // Target related

        let c = getC(phi: CGFloat(model.phiC), theta: CGFloat(model.thetaC), d: getD(tether: CGFloat(model.tetherLength), r: CGFloat(model.turningRadius)))

        if c.norm > 0 && model.pursuits.count > 0 {
            let p = model.pursuit(at: time).val

            let piPlane = Plane(center: c, normal: c.unit)
            let target = piPlane.deCollapse(point: p.target)
            if let loc = steppedConfigurations.first?.loc, loc.vel.norm > 0 {
                let radius = Scalar(p.arcRadius)
                let center = loc.pos - radius*(piPlane.normal×loc.vel).unit

                let (arcAngle2, center2point, radius2) = Pursuit.angleCenterRadius(position: p.pos, target: p.target, attitude: p.vel.norm > 0 ? p.vel.unit : CGPoint(x: 1, y: 0))
                let center2 = piPlane.deCollapse(point: center2point)

                arcData = (radius, center, arcAngle2, radius2, center2, target, c)
            }
        }

        change.onNext(.scrubbed)
    }

    private func configuration(for time: TimeInterval) -> TimedConfiguration {
        return (model.location(at: time).val, model.orientation(at: time).val)
    }

    private func absolute(_ rel: Scalar) -> TimeInterval {
        return model.start + model.duration*Double(rel)
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
            let p = LogProcessor.shared.steppedConfigurations.first?.loc.pos ?? .zero
            self.currentPositionLabel.stringValue = String(format: "NED: %.1f, %.1f, %.1f", p.x, p.y, p.z)
            self.tLabel.stringValue = String(format: "%.2f", LogProcessor.shared.time)
            }
            .disposed(by: bag)

        let stepCount = stepSlider.scalar.map { Int(round($0*$0)) }.shareReplayLatestWhileConnected()
        stepCount.map { String(format: "%.1f", LogProcessor.shared.model.duration/Double($0)) }.bind(to: stepLabel.rx.text).disposed(by: bag)
        stepCount.bind { LogProcessor.shared.stepCount = $0 }.disposed(by: bag)

        loadButton.rx.tap.bind(onNext: openFile).disposed(by: bag)
        clearButton.rx.tap.bind { LogProcessor.shared.clear() }.disposed(by: bag)
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.begin { result in
            if result == NSFileHandlingPanelOKButton {
                self.load(panel.urls[0])
            }
        }
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
            TimedPursuitLog(time: $0.timestamp, rollRate: $0.value("roll_rate"), arcRadius: $0.value("arc_radius"), posX: $0.value("x"), posY: $0.value("y"), velX: $0.value("vx"), velY: $0.value("vy"), targetX: $0.value("tx"), targetY: $0.value("ty"))
        }

        let model = LogModel(tetherLength: tetherLength, posB: posB, phiC: phiC, thetaC: thetaC, turningRadius: turningRadius, locations: locations, orientations: orientations, actuators: actuators, pursuits: pursuits)
        LogProcessor.shared.load(model)
        
        
        let pitchSP: [TimedValue] = parser.read("vehicle_attitude_setpoint") { TimedValue(time: $0.timestamp, value: $0.value("pitch_body") ) }
        let pitch: [TimedValue] = parser.read("vehicle_attitude") { TimedValue(time: $0.timestamp, value: Euler(q: $0.quaternion("q")).theta ) }
        
//        print(pitchSP)
//        print(pitchSP.count)
//        print(pitch.count)
        pitch.forEach { print( $0.value ) }
        
//        print(pitch)
        
        
        
//        print(parser)
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


