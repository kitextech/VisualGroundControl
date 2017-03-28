//
//  SceneViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-02-25.
//  Copyright (c) 2017 Gustaf Kugelberg. All rights reserved.
//

import SceneKit
import QuartzCore
import RxSwift
import RxCocoa

func noOp<T>(value: T) -> T { return value }
func makeScalar(_ value: Double) -> Scalar { return Scalar(value) }

func ignore<T>(value: T) { }
func isOn(int: Int) -> Bool { return int == 1 }

func log<T>(as name: String) -> (T) -> Void {
    return { print(name + ": \($0)") }
}

func makeQuaternion(euler: Vector) -> Quaternion {
    let cosPhi2 = cos(euler.x/2)
    let sinPhi2 = sin(euler.x/2)

    let cosTheta2 = cos(euler.y/2)
    let sinTheta2 = sin(euler.y/2)

    let cosPsi2 = cos(euler.z/2)
    let sinPsi2 = sin(euler.z/2)

    let x = sinPhi2*cosTheta2*cosPsi2 - cosPhi2*sinTheta2*sinPsi2
    let y = cosPhi2*sinTheta2*cosPsi2 + sinPhi2*cosTheta2*sinPsi2
    let z = cosPhi2*cosTheta2*sinPsi2 - sinPhi2*sinTheta2*cosPsi2
    let w = cosPhi2*cosTheta2*cosPsi2 + sinPhi2*sinTheta2*sinPsi2

//    print("Euler: (\(euler.x) \(euler.y) \(euler.z)) -> Q: \(Quaternion(x, y, z, w))")

    return Quaternion(x, y, z, w)
}


let π = Scalar(M_PI)

public let e_x = Vector.ex
public let e_y = Vector.ey
public let e_z = Vector.ez

protocol KiteType {
    var position: PublishSubject<Vector> { get }
    var attitude: PublishSubject<Matrix> { get }
    var velocity: PublishSubject<Vector> { get }
}

//protocol AnalyserType {
//    // Input
//    var position: Variable<Vector> { get }
//    var attitude: Variable<Matrix> { get }
//    var velocity: Variable<Vector> { get }
//    
//    // Output
//    var estimatedWind: PublishSubject<Vector?> { get }
//    var tetherPoint: PublishSubject<Vector?> { get }
//    var turningPoint: PublishSubject<Vector?> { get }
//    var turningRadius: PublishSubject<Scalar?> { get }
//    var isTethered: PublishSubject<Scalar> { get }
//}

final class SceneViewController: NSViewController, SCNSceneRendererDelegate {
    @IBOutlet weak var sceneView: SCNView!
    @IBOutlet weak var overlay: TraceView!

    private let bag = DisposeBag()
    private let emulator = KiteEmulator()
    
    private let leap = LeapListener.shared
    private let kite = KiteLink.shared
    
    private let viewer = KiteViewer()
    
    private let wind = Variable<Vector>(.zero)

    // MARK: - Overall Settings

    // MARK: - Real Kite Settings

    // Position Popover Touchbar
    @IBOutlet weak var xSlider: NSSlider!
    @IBOutlet weak var ySlider: NSSlider!
    @IBOutlet weak var zSlider: NSSlider!

    // Position Popover Touchbar
    @IBOutlet weak var pitchSlider: NSSlider!
    @IBOutlet weak var rollSlider: NSSlider!
    @IBOutlet weak var thrustSlider: NSSlider!

    // MARK: - Kite Emulator Settings

    // Wind Popover Touchbar
    @IBOutlet weak var windSpeedSlider: NSSlider!
    @IBOutlet weak var windDirectionSlider: NSSlider!
    
    // Kite Popover Touchbar
    @IBOutlet weak var elevationSlider: NSSlider!
    @IBOutlet weak var glideSlider: NSSlider!
    
    // General Popover Touchbar
    @IBOutlet weak var tetherLengthSlider: NSSlider!
    @IBOutlet weak var turningRadiusSlider: NSSlider!

    // Tweaks Popover Touchbar
    @IBOutlet weak var phiDeltaSlider: NSSlider!
    @IBOutlet weak var rollDeltaSlider: NSSlider!
    @IBOutlet weak var pitchDeltaSlider: NSSlider!
    @IBOutlet weak var phaseDeltaSlider: NSSlider!
    
    // MARK: - Kite Viewer Settings
    @IBOutlet weak var kiteAxesButton: NSButton!
    @IBOutlet weak var piAxesButton: NSButton!
    @IBOutlet weak var piPlaneButton: NSButton!
    @IBOutlet weak var velocityButton: NSButton!
    @IBOutlet weak var windButton: NSButton!
    @IBOutlet weak var tetherButton: NSButton!
    @IBOutlet weak var kiteButton: NSButton!

    // Timer

    private var lastUpdate: TimeInterval = 0
    private var isPaused = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewer.setup(with: sceneView)
        sceneView.delegate = self
        sceneView.isPlaying = true
        sceneView.showsStatistics = true

//        leap.start()
//
//        leap.rightHand.bindNext { hand in
//            print("hand: \(hand.palmPosition)")
//        }.disposed(by: bag)

//        realKite.mavlinkMessage.subscribe(onNext: { print("MESSAGE: \($0)") }).disposed(by: bag)
//        realKite.location.subscribe(onNext: { print("LOCATION: \($0)") }).disposed(by: bag)
        
        // Emulator parameters
        
        // Wind
        windSpeedSlider.setup(min: 0, max: 20, current: 10)
        windDirectionSlider.setup(min: -π, max: π, current: π/4)
        
        Observable.combineLatest(windSpeedSlider.scalar, windDirectionSlider.scalar, resultSelector: getWind).bindTo(wind).disposed(by: bag)
        wind.asObservable().bindTo(emulator.wind).disposed(by: bag)
        
        // Kite
        elevationSlider.setup(min: 0, max: π/2, current: 0)
        elevationSlider.scalar.bindTo(emulator.elevation).disposed(by: bag)
        
        glideSlider.setup(min: 2, max: 4, current: 3)
        glideSlider.scalar.bindTo(emulator.speedFactor).disposed(by: bag)
        
        // General
        tetherLengthSlider.setupExp(min: 30, max: 250, current: 100)
        tetherLengthSlider.expScalar(min: 30, max: 250).bindTo(kite.tetherLength).disposed(by: bag)
        
        turningRadiusSlider.setupExp(min: 10, max: 100, current: 20)
        turningRadiusSlider.expScalar(min: 10, max: 100).bindTo(kite.turningRadius).disposed(by: bag)
        
        phaseDeltaSlider.setup(min: -π, max: π, current: 0)
        phaseDeltaSlider.scalar.bindTo(emulator.phaseDelta).disposed(by: bag)
        
        // Tweaks
        phiDeltaSlider.setup(min: -π/8, max: π/8, current: 0)
        phiDeltaSlider.scalar.bindTo(emulator.phiDelta).disposed(by: bag)
        
        rollDeltaSlider.setup(min: -π/8, max: π/8, current: 0)
        rollDeltaSlider.scalar.bindTo(emulator.rollDelta).disposed(by: bag)
        
        pitchDeltaSlider.setup(min: -π/8, max: π/8, current: 0)
        pitchDeltaSlider.scalar.bindTo(emulator.pitchDelta).disposed(by: bag)

        // Real Kite Position Target

        xSlider.setup(min: -10, max: 10, current: 0)
        ySlider.setup(min: -10, max: 10, current: 0)
        zSlider.setup(min: 2, max: 12, current: 2)

        let positionTarget = Variable<Vector>(.zero)
        Observable.combineLatest(xSlider.scalar, ySlider.scalar, zSlider.scalar.map(-), resultSelector: Vector.fromScalars).bindTo(positionTarget).disposed(by: bag)

        positionTarget.asObservable().bindTo(viewer.positionTarget).disposed(by: bag)
        positionTarget.asObservable().bindTo(kite.positionTarget).disposed(by: bag)

        // Kite Attitude Target

        pitchSlider.setup(min: -π/8, max: π/8, current: 0)
        rollSlider.setup(min: -π/8, max: π/8, current: 0)

        func makeEuler(pitch: Scalar, roll: Scalar, yaw: Scalar) -> Vector {
            return Vector(pitch, roll, yaw)
        }

        let euler = Variable<Vector>(.zero)

        Observable.combineLatest(pitchSlider.scalar, rollSlider.scalar, thrustSlider.scalar, resultSelector: makeEuler)
            .bindTo(euler)
            .disposed(by: bag)

        euler.asObservable()
            .map(makeQuaternion)
            .bindTo(kite.attitudeTarget)
            .disposed(by: bag)

//        euler.asObservable()
//            .map(makeMatrix)
//            .bindTo(viewer.attitude)
//            .disposed(by: bag)

        thrustSlider.setup(min: 0, max: 1*π, current: 0)
//        thrustSlider.scalar.bindTo(kite.thrust).disposed(by: bag)

        // Kite Position

        func getPoint(loc: KiteLocation) -> NSPoint {
            return NSPoint(x: loc.pos.x/30 + 0.5, y: loc.pos.y/30 + 0.5)
        }

        let location = Variable<KiteLocation>(KiteLocation())

        kite.location.bindTo(location).disposed(by: bag)

        let velocity = Variable<Vector>(.zero)
        location.asObservable().map(KiteLocation.getVelocity).bindTo(velocity).disposed(by: bag)
        velocity.asObservable().bindTo(viewer.velocity).disposed(by: bag)
//        velocity.asObservable().bindTo(overlay.velocity).disposed(by: bag)

        let position = Variable<Vector>(.zero)
        location.asObservable().map(KiteLocation.getPosition).bindTo(position).disposed(by: bag)
        position.asObservable().bindTo(viewer.position).disposed(by: bag)
        position.asObservable().bindTo(overlay.position).disposed(by: bag)

//        kite.location.map(getPoint).subscribe(onNext: overlay.add).disposed(by: bag)

        // Kite Attitude

        // Emulator Output
//        emulator.position.bindTo(viewer.position).disposed(by: bag)
//        emulator.velocity.bindTo(viewer.velocity).disposed(by: bag)
//        emulator.attitude.bindTo(viewer.attitude).disposed(by: bag)
//
//        kite.turningPoint.bindTo(viewer.turningPoint).disposed(by: bag)

//        tetherPoint.asObservable().bindTo(viewer.tetherPoint).disposed(by: bag)

//        kite.attitude.map(KiteAttitude.getAttitude).map(Matrix.init).bindTo(viewer.attitude).disposed(by: bag)


        let quaternion = Variable<Quaternion>(.id)
        kite.quaternion.map(KiteQuaternion.getQuaternion).bindTo(quaternion).disposed(by: bag)

        print("Binding kite quaternion to scene")
        quaternion.asObservable().bindTo(viewer.quaternion).disposed(by: bag)

        print("Binding kite quaternion to overlay")
        quaternion.asObservable().bindTo(overlay.quaternion).disposed(by: bag)

//        quaternion.asObservable().subscribe(onNext: { print("Q: \($0)") }).disposed(by: bag)

        // Kite viewer parameters
        wind.asObservable().bindTo(viewer.wind).disposed(by: bag)
        
        // Kite viewer settings
        bind(button: kiteAxesButton, to: .kiteAxes)
        bind(button: piAxesButton, to: .piAxes)
        bind(button: piPlaneButton, to: .piPlane)
        bind(button: velocityButton, to: .velocity)
        bind(button: windButton, to: .wind)
        bind(button: tetherButton, to: .tether)
        bind(button: kiteButton, to: .kite)

//        kite.quaternion.bindNext { kq in
//            let q = kq.quaternion
//            print("Q: \(q.x) \(q.y) \(q.z) \(q.w)")
//            }.disposed(by: bag)
//
//        kite.attitude.bindNext { ka in
//            let a = ka.att
//            print("E: \(a.x) \(a.y) \(a.z)")
//            }.disposed(by: bag)
    }
    
    private func togglePause(paused: Bool) {
        isPaused = paused
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if isPaused {
            emulator.update()
        }
        else {
            emulator.update(elapsed: time - lastUpdate)
        }
        
        lastUpdate = time
    }
    
    override func keyDown(with event: NSEvent) {
        
    }
    
    // MARK: Helper Functions
    
    private func bind(button: NSButton, to element: ViewerElement) {
        button.rx.state
            .map(isOn)
            .map(combine(with: element))
            .bindNext(viewer.changeVisibility)
            .disposed(by: bag)
    }
    
    private func getWind(r: Scalar, phi: Scalar) -> Vector {
        return r*e_x.rotated(around: e_z, by: phi)
    }
    
    private func combine<S, T>(with element: T) -> (S) -> (S, T) {
        return {
            return ($0, element)
        }
    }
}

extension NSSlider {
    func setup(min minVal: Scalar, max maxVal: Scalar, current: Scalar) {
        minValue = Double(minVal)
        maxValue = Double(maxVal)
        doubleValue = Double(current)
    }
    
    var scalar: Observable<Scalar> {
        return self.rx.value.map(makeScalar)
    }

    func setupExp(min minVal: Scalar, max maxVal: Scalar, current: Scalar) {
        minValue = 0
        maxValue = 1
        doubleValue = Double(log(current/minVal)/log(maxVal/minVal))
    }
    
    func expScalar(min minVal: Scalar, max maxVal: Scalar) -> Observable<Scalar> {
        return rx.value.map { minVal*exp(log(maxVal/minVal)*Scalar($0)) }
    }
}

extension NSButton {
    var bool: Observable<Bool> {
        return rx.state.map(isOn)
    }
}
