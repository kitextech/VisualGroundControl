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

func makeVector(_ value: (Scalar, Scalar, Scalar)) -> Vector { return Vector(value.0, value.1, value.2) }

func makeVec(_ x: Scalar, y: Scalar, z: Scalar) -> Vector { return Vector(x, y, z) }

func ignore<T>(value: T) { }
func isOn(int: Int) -> Bool { return int == 1 }

func log<T>(as name: String) -> (T) -> Void {
    return { print(name + ": \($0)") }
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

protocol AnalyserType {
    // Input
    var position: Variable<Vector> { get }
    var attitude: Variable<Matrix> { get }
    var velocity: Variable<Vector> { get }
    
    // Output
    var estimatedWind: PublishSubject<Vector?> { get }
    var tetherPoint: PublishSubject<Vector?> { get }
    var turningPoint: PublishSubject<Vector?> { get }
    var turningRadius: PublishSubject<Scalar?> { get }
    var isTethered: PublishSubject<Scalar> { get }
}

final class SceneViewController: NSViewController, SCNSceneRendererDelegate {
    @IBOutlet weak var sceneView: SCNView!
    
    private let bag = DisposeBag()
    private let kite = KiteEmulator()
    
    private let leap = LeapListener.shared
    private let realKite = KiteLink.shared
    
    private let viewer = KiteViewer()
    
    private let wind = Variable<Vector>(.zero)

    // MARK: - Overall Settings
    
    @IBOutlet weak var pauseButton: NSButton!
    
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
        
        pauseButton.bool.subscribe(onNext: togglePause).disposed(by: bag)
        
        leap.start()

        leap.rightHand.bindNext { hand in
            print("hand: \(hand.palmPosition)")
        }.disposed(by: bag)
        
//        realKite.mavlinkMessage.subscribe(onNext: { print("MESSAGE: \($0)") }).disposed(by: bag)
//        realKite.location.subscribe(onNext: { print("LOCATION: \($0)") }).disposed(by: bag)
        
        // Kite emulator parameters
        
        // Wind
        windSpeedSlider.setup(min: 0, max: 20, current: 10)
        windDirectionSlider.setup(min: -π, max: π, current: π/4)
        
        Observable.combineLatest(windSpeedSlider.scalar, windDirectionSlider.scalar, resultSelector: getWind).bindTo(wind).disposed(by: bag)
        wind.asObservable().bindTo(kite.wind).disposed(by: bag)
        
        // Kite
        elevationSlider.setup(min: 0, max: π/2, current: 0)
        elevationSlider.scalar.bindTo(kite.elevation).disposed(by: bag)
        
        glideSlider.setup(min: 2, max: 4, current: 3)
        glideSlider.scalar.bindTo(kite.speedFactor).disposed(by: bag)
        
        // General
        tetherLengthSlider.setupExp(min: 30, max: 250, current: 100)
        tetherLengthSlider.expScalar(min: 30, max: 250).bindTo(kite.tetherLength).disposed(by: bag)
        
        turningRadiusSlider.setupExp(min: 10, max: 100, current: 20)
        turningRadiusSlider.expScalar(min: 10, max: 100).bindTo(kite.turningRadius).disposed(by: bag)
        
        phaseDeltaSlider.setup(min: -π, max: π, current: 0)
        phaseDeltaSlider.scalar.bindTo(kite.phaseDelta).disposed(by: bag)
        
        // Tweaks
        phiDeltaSlider.setup(min: -π/8, max: π/8, current: 0)
        phiDeltaSlider.scalar.bindTo(kite.phiDelta).disposed(by: bag)
        
        rollDeltaSlider.setup(min: -π/8, max: π/8, current: 0)
        rollDeltaSlider.scalar.bindTo(kite.rollDelta).disposed(by: bag)
        
        pitchDeltaSlider.setup(min: -π/8, max: π/8, current: 0)
        pitchDeltaSlider.scalar.bindTo(kite.pitchDelta).disposed(by: bag)


        let tetherPoint = Variable<Vector>(.zero)

        Observable.combineLatest(phiDeltaSlider.scalar, rollDeltaSlider.scalar, pitchDeltaSlider.scalar, resultSelector: makeVector).bindTo(tetherPoint).disposed(by: bag)

        tetherPoint.asObservable().bindTo(kite.tetherPoint).disposed(by: bag) // new

        // Kite Emulator Output
        kite.position.bindTo(viewer.position).disposed(by: bag)
        kite.velocity.bindTo(viewer.velocity).disposed(by: bag)
        kite.attitude.bindTo(viewer.attitude).disposed(by: bag)
        
        kite.turningPoint.bindTo(viewer.turningPoint).disposed(by: bag)

        tetherPoint.asObservable().bindTo(viewer.tetherPoint).disposed(by: bag) // new

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
    }
    
    private func togglePause(paused: Bool) {
        isPaused = paused
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if isPaused {
            kite.update()
        }
        else {
            kite.update(elapsed: time - lastUpdate)
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

class TraceView: NSView {
    private var points = [NSPoint]()
    
    private var path = NSBezierPath()
    
    public func add(point: NSPoint) {
        points.append(point)
        
        path.line(to: scaler(rect: bounds)(point))

        setNeedsDisplay(bounds)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        path.stroke()
    }
}

private func scaler(rect: NSRect) -> (NSPoint) -> NSPoint {
    return { point in
        NSPoint(x: rect.minX + rect.width*point.x, y: rect.minY + rect.height*point.y)
    }
}

//        Observable.combineLatest(windSlider.rx.value, vSlider.rx.value, hSlider.rx.value, resultSelector: Vector.init)
//            .bindTo(viewer.attitude).disposed(by: bag)

//        Observable.combineLatest(vSlider.rx.value, hSlider.rx.value, windSlider.rx.value, resultSelector: noOp)
//            .map { Matrix(rotation: .ex, by: Scalar($0.0))*Matrix(rotation: .ey, by: Scalar($0.1))*Matrix(rotation: .ez, by: Scalar($0.2)) }
//            .subscribe(onNext: { self.viewer.ship.pivot = $0 })
//            .disposed(by: bag)
