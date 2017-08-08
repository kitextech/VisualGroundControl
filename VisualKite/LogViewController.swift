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

        return LogMNodel(duration: duration, locations: locations, orientations: orientations)
    }()
}

struct LogProcessor {
    enum Change { case scrubbed, changedRange }

    public let change = PublishSubject<Change>()

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
    public var strodePositions: [Vector] = []
    public var positions: [Vector] = []
    public var velocities: [Vector] = []
    public var orientations: [Quaternion] = []

//    public var angularVelocities: [Vector] = []

    private var model: LogMNodel = LogLoader().loadData() ?? .test

    public mutating func load(_ newModel: LogMNodel) {
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
            position = .zero
            velocity = .zero
            orientation = .id
            return
        }

        let tRel = t0Rel*(1 - tRelRel) + t1Rel*tRelRel
        time = duration*Double(tRel)
        let i = index(for: tRel)
        position = model.locations[i].pos
        velocity = model.locations[i].vel
        orientation = model.orientations[i].orientation
        change.onNext(.scrubbed)
    }

    private mutating func updateVisible() {
        guard !model.isEmpty else {
            positions = []
            velocities = []
            orientations = []
            return
        }

        let range = index(for: t0Rel)...index(for: t1Rel)
        positions = model.locations[range].map(TimedLocation.getPosition)

        let strodeRange = stride(from: index(for: t0Rel), to: index(for: t1Rel), by: step)
        let visibleLocations = strodeRange.map { model.locations[$0] }
        strodePositions = visibleLocations.map(TimedLocation.getPosition)
        velocities = visibleLocations.map(TimedLocation.getVelocity)
        orientations = strodeRange.map { model.orientations[$0].orientation }
        change.onNext(.changedRange)
    }

    private func index(for rel: Scalar) -> Int {
        return Int(round(rel*Scalar(model.locations.count - 1)))
    }
}

class LogLoader {

    func loadData() -> LogMNodel? {
                let path = "~/Dropbox/KiteX/PrototypeDesign/10_32_17.ulg"
//        let path = "/Users/aokholm/src/kitex/PX4/Firmware/build_posix_sitl_default_replay/tmp/rootfs/fs/microsd/log/2017-08-04/15_19_22_replayed.ulg"
        
        let location = NSString(string: path).expandingTildeInPath
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: location)) else {
            print("failed to load data")
            return nil
        }
        
        guard let ulog = ULog(data: data) else {
            print("error")
            return nil
        }
        
//        let messageName = "fw_turning"
//        let variableKey = "arc_radius"
//        
//        let f = ulog.formats[messageName]!
//        let sensorCombinedData = ulog.data[messageName]!
//        
//        let variableIndex = f.lookup[variableKey]!
//        
//        let variableArray = sensorCombinedData.map { $0[variableIndex] }
        
//        public let duration: Double
//        public let locations: [TimedLocation]
//        public let orientations: [TimedOrientation]
        
        
        let vehicleLocalPositions = ulog.data["vehicle_local_position"]!
        let VLPf = ulog.formats["vehicle_local_position"]!
        
        print(VLPf)
        
        func toTimedLocation(value: [UlogValue] ) -> TimedLocation {
            
            let time = value[VLPf.lookup["timestamp"]!].getValue() as UInt64
            
            let x = value[VLPf.lookup["x"]!].getValue() as Float
            let y = value[VLPf.lookup["y"]!].getValue() as Float
            let z = value[VLPf.lookup["z"]!].getValue() as Float
            let vx = value[VLPf.lookup["vx"]!].getValue() as Float
            let vy = value[VLPf.lookup["vy"]!].getValue() as Float
            let vz = value[VLPf.lookup["vz"]!].getValue() as Float
            let pos = Vector(x,y,z)
            let vel = Vector(vx,vy,vz)

            return TimedLocation(time: Double(time)/1000000, pos: pos, vel: vel)
            
        }
        
        let VAf = ulog.formats["vehicle_attitude"]!

        func toTimedOrientation(value: [UlogValue] ) -> TimedOrientation {
            
            let time = value[VAf.lookup["timestamp"]!].getValue() as UInt64
            let qarray = value[VAf.lookup["q"]!].getValue() as [UlogValue]
            
            let w = qarray[0].getValue() as Float
            let x = qarray[1].getValue() as Float
            let y = qarray[2].getValue() as Float
            let z = qarray[3].getValue() as Float

            return TimedOrientation(time: Double(time)/1000000, orientation: Quaternion(x, y, z, w), rate: Vector(0,0,0))
            
        }
        
        let timedLocations = vehicleLocalPositions.map(toTimedLocation)
        let timedOrientations = ulog.data["vehicle_attitude"]!.map(toTimedOrientation)

//        print(timedLocations)
//
//        print(timedOrientations)

        return LogMNodel(duration: 180, locations: timedLocations, orientations: timedOrientations)
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
        
//        let logLoader = LogLoader.init()
//        logLoader.loadData()
        
        let tRelRel = tSlider.scalar.shareReplayLatestWhileConnected()
        let t0Rel = t0Slider.scalar.shareReplayLatestWhileConnected()
        let t1Rel = t1Slider.scalar.shareReplayLatestWhileConnected()

        tRelRel.bind { LogProcessor.shared.tRelRel = $0 }.disposed(by: bag)
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




