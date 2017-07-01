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

    @IBOutlet weak var xzButton: NSButton!
    @IBOutlet weak var yzButton: NSButton!
    @IBOutlet weak var piButton: NSButton!

    // MARK: - Private

    private let bag = DisposeBag()

    // MARK: - View Controller Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        freeView.phi = π/2 - 0.2
        freeView.theta = 0
        freeView.scrolls = true

        // Kites

        add(KiteController.kite0, color: .purple)
        add(KiteController.kite1, color: .orange)

        // The dome

        KiteController.shared.settings.tetherLength.asObservable()
            .bind { radius in self.freeView.domeRadius = radius; self.xyView.domeRadius = radius }
            .disposed(by: bag)

        // Coordinate axes

        let axes = [(e_x, NSColor.red), (e_y, .green), (e_z, .blue)].map { ArrowDrawable(vector: 5*$0, color: $1) }
        axes.forEach(add)

        // C and the path

        let tetherLength = KiteController.shared.settings.tetherLength.asObservable()
        let turningRadius = KiteController.shared.settings.turningRadius.asObservable()
        let d = Observable.combineLatest(tetherLength, turningRadius, resultSelector: getD)

        let phiC = KiteController.shared.settings.phiC.asObservable()
        let thetaC = KiteController.shared.settings.thetaC.asObservable()

        let cPoint = Observable.combineLatest(phiC, thetaC, d, resultSelector: getC)

        let cDrawable = BallDrawable(color: .green)
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

        Observable.merge(xyView.requestedPosition0.asObservable(), freeView.requestedPosition0.asObservable())
            .distinctUntilChanged()
            .bind(to: KiteController.kite0.positionTarget)
            .disposed(by: bag)

        Observable.merge(xyView.requestedPosition1.asObservable(), freeView.requestedPosition1.asObservable())
            .distinctUntilChanged()
            .bind(to: KiteController.kite1.positionTarget)
            .disposed(by: bag)

        KiteController.kite0.positionTarget.asObservable().bind(to: xyView.requestedPosition0).disposed(by: bag)
        KiteController.kite0.positionTarget.asObservable().bind(to: freeView.requestedPosition0).disposed(by: bag)

        KiteController.kite1.positionTarget.asObservable().bind(to: xyView.requestedPosition1).disposed(by: bag)
        KiteController.kite1.positionTarget.asObservable().bind(to: freeView.requestedPosition1).disposed(by: bag)

        // Redrawing

        cPoint
            .bind { _ in self.freeView.redraw(); self.xyView.redraw() }
            .disposed(by: bag)

//        xzButton.rx.tap.map { (0, π/2) }.bind(to: freeView.angles).disposed(by: bag)
//        yzButton.rx.tap.map { (π/2, π/2) }.bind(to: freeView.angles).disposed(by: bag)
//        piButton.rx.tap.map { (π + kite.phiC.value, π/2 - kite.thetaC.value) }.bind(to: freeView.angles).disposed(by: bag)
    }

    // Helper methods

    private func add(_ drawable: Drawable) {
        xyView.add(drawable)
        freeView.add(drawable)
    }

    private func add(_ kite: KiteLink, color: NSColor) {
        let drawable = KiteDrawable(color: color)
        add(drawable)

        kite.location
            .map(TimedLocation.getPosition)
            .bind { pos in drawable.position = pos }
            .disposed(by: bag)

        kite.quaternion
            .map(TimedQuaternion.getQuaternion)
            .bind { q in drawable.orientation = q }
            .disposed(by: bag)

        // Target position

        let targetDrawable = BallDrawable(color: color)
        add(targetDrawable)

        kite.positionTarget.asObservable()
            .bind { pos in targetDrawable.position = pos }
            .disposed(by: bag)
    }

    private func getD(tether: Scalar, r: Scalar) -> Scalar {
        return sqrt(tether*tether - r*r)
    }

    private func getC(phi: Scalar, theta: Scalar, d: Scalar) -> Vector {
        return Vector(phi: phi, theta: π/2 + theta, r: d)
    }

//    private func getCKite(phi: Scalar, theta: Scalar, d: Scalar) -> Vector {
//        let xyFactor = d*cos(theta);
//        return Vector(xyFactor*cos(phi), xyFactor*sin(phi), -d*sin(theta))
//    }
}

extension AffineTransform {
    init(translationBy point: CGPoint) {
        self = AffineTransform(translationByX: point.x, byY: point.y)
    }
}
