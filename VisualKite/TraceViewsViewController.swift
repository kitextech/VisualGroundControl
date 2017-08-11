//
//  TraceViewsViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-18.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import RxSwift
import QuartzCore

func map<S, T>(f: @escaping (S) -> T) -> ([S]) -> [T] {
    return { $0.map(f) }
}

class TraceViewsViewController: NSViewController {
    // MARK: - Parameters

    // MARK: - Outlets

    @IBOutlet weak var xyView: TraceView!
    @IBOutlet weak var freeView: TraceView!

    @IBOutlet weak var slider: NSSlider!

    @IBOutlet weak var xzButton: NSButton!
    @IBOutlet weak var yzButton: NSButton!
    @IBOutlet weak var piButton: NSButton!

    // MARK: - Private

    private let bag = DisposeBag()
    private var views: [TraceView] = []

    private let pathLogDrawable = PathDrawable()
    private let velocitiesLogDrawable = ArrowsDrawable(color: .orange)
    private let orientationsLogDrawableX = ArrowsDrawable(color: .red)
    private let orientationsLogDrawableY = ArrowsDrawable(color: .green)
    private let orientationsLogDrawableZ = ArrowsDrawable(color: .blue)

    private var currentPositionLogDrawable = KiteDrawable(color: .red)

    // MARK: - View Controller Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        freeView.phi = π/2 - 0.2
        freeView.theta = 0
        freeView.scrolls = true

        views = [xyView, freeView]

        // Kites

        add(KiteController.kite0, color: .purple)
        add(KiteController.kite1, color: .orange)

        // The dome

        KiteController.shared.settings.tetherLength.asObservable()
            .bind { radius in self.views.forEach { $0.domeRadius = radius } }
            .disposed(by: bag)

        // Coordinate axes

        let axes = [(e_x, NSColor.red), (e_y, .green), (e_z, .blue)].map { ArrowDrawable(vector: 10*$0, color: $1) }
        axes.forEach(add)

        // C and the path

        let tetherLength = KiteController.shared.settings.tetherLength.asObservable()
        let turningRadius = KiteController.shared.settings.turningRadius.asObservable()
        let d = Observable.combineLatest(tetherLength, turningRadius, resultSelector: getD)

        let phiC = KiteController.shared.settings.phiC.asObservable()
        let thetaC = KiteController.shared.settings.thetaC.asObservable()

        let cPoint = Observable.combineLatest(phiC, thetaC, d, resultSelector: getC)

        let cDrawable = BallDrawable(color: .red)
        add(cDrawable)

        cPoint
            .bind { pos in cDrawable.position = pos}
            .disposed(by: bag)

        let piCircleDrawable = CircleDrawable()
        add(piCircleDrawable)

        cPoint
            .bind { pos in piCircleDrawable.position = pos; piCircleDrawable.normal = pos.unit }
            .disposed(by: bag)

        KiteController.shared.settings.turningRadius.asObservable()
            .bind { radius in piCircleDrawable.radius = radius }
            .disposed(by: bag)

        // Trace views as controls

        let requestedPositions = [KiteController.kite0.positionTarget, KiteController.kite1.positionTarget]
        views.forEach { $0.requestedPositions = requestedPositions }

        // Redrawing

        requestedPositions.map { $0.asObservable() }.forEach(useAsRedrawTrigger)
        useAsRedrawTrigger(cPoint)
        redrawViews()

//        xzButton.rx.tap.map { (0, π/2) }.bind(to: freeView.angles).disposed(by: bag)
//        yzButton.rx.tap.map { (π/2, π/2) }.bind(to: freeView.angles).disposed(by: bag)
//        piButton.rx.tap.map { (π + kite.phiC.value, π/2 - kite.thetaC.value) }.bind(to: freeView.angles).disposed(by: bag)

        [currentPositionLogDrawable, pathLogDrawable, velocitiesLogDrawable, orientationsLogDrawableX, orientationsLogDrawableY, orientationsLogDrawableZ].forEach(add)

        LogProcessor.shared.change.bind(onNext: updateLogPaths).disposed(by: bag)
    }

    // Helper methods

    private func useAsRedrawTrigger<T>(_ observable: Observable<T>) {
        observable.bind { _ in self.redrawViews() }.disposed(by: bag)
    }

    private func redrawViews() {
        views.forEach { $0.redraw() }
    }

    private func add(_ drawable: Drawable) {
        views.forEach { $0.add(drawable) }
    }

    private func add(_ kite: KiteLink, color: NSColor) {
        let drawable = KiteDrawable(color: color)
        add(drawable)

        kite.location
            .map(TimedLocation.getPosition)
            .bind { pos in drawable.position = pos }
            .disposed(by: bag)

        kite.orientation
            .map(TimedOrientation.getQuaternion)
            .bind { q in drawable.orientation = q }
            .disposed(by: bag)

        // Target position

        let targetDrawable = BallDrawable(color: color)
        add(targetDrawable)

        kite.positionTarget.asObservable()
            .bind { pos in targetDrawable.position = pos }
            .disposed(by: bag)

        useAsRedrawTrigger(kite.location)
        useAsRedrawTrigger(kite.orientation)
    }

    private func updateLogPaths(_ change: LogProcessor.Change) {
        //        LogProcessor.shared.tRelRel = tRelRel

        currentPositionLogDrawable.position = LogProcessor.shared.position

        if change == .changedRange {
            pathLogDrawable.update(LogProcessor.shared.positions)

            let strodePositions = LogProcessor.shared.strodePositions
            //        velocitiesLogDrawable.update(strodePositions, LogProcessor.shared.velocities)

            func update(_ drawable: ArrowsDrawable, _ vector: Vector) {
                drawable.update(strodePositions, LogProcessor.shared.orientations.map { 3*$0.apply(vector) })
            }

            update(orientationsLogDrawableX, e_x)
            update(orientationsLogDrawableY, e_y)
            update(orientationsLogDrawableZ, e_z)
        }

        redrawViews()
    }

    private func getD(tether: Scalar, r: Scalar) -> Scalar {
        return sqrt(tether*tether - r*r)
    }

    private func getC(phi: Scalar, theta: Scalar, d: Scalar) -> Vector {
        return Vector(phi: phi, theta: π/2 + theta, r: d)
    }
}

extension AffineTransform {
    init(translationBy point: CGPoint) {
        self = AffineTransform(translationByX: point.x, byY: point.y)
    }
}
