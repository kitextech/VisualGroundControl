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
import AVKit
import AVFoundation

func map<S, T>(f: @escaping (S) -> T) -> ([S]) -> [T] {
    return { $0.map(f) }
}

class TraceViewsViewController: NSViewController {
    // MARK: - Parameters

    // MARK: - Outlets

    @IBOutlet weak var logLabel: NSTextField!

    @IBOutlet weak var freeView: TraceView!
    @IBOutlet weak var videoView: AVPlayerView!

    @IBOutlet weak var xzButton: NSButton!
    @IBOutlet weak var yzButton: NSButton!
    @IBOutlet weak var piButton: NSButton!

    @IBOutlet weak var loadButton: NSButton!

    @IBOutlet weak var videoOffset: NSSlider!

    // MARK: - Private

    private let bag = DisposeBag()
    private var views: [TraceView] = []

    private let cDrawable = BallDrawable(color: .red)
    private let piCircleDrawable = CircleDrawable()

    private let velocityLogDrawable = ArrowDrawable(color: .orange, hideBall: true)
    private let targetLogDrawable = BallDrawable(color: .orange)

    private let arcLogDrawable = ArcDrawable(color: .orange)
    private let arcCenterLogDrawable = BallDrawable(color: .orange)

    private let arc2LogDrawable = CircleDrawable(color: .purple)
    private let arcCenter2LogDrawable = BallDrawable(color: .purple)

    private let circleLogDrawable = CircleDrawable()
    private let pathLogDrawable = PathDrawable()
    private var steppedLogDrawables = [KiteDrawable(color: .red)]

    // MARK: - View Controller Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        freeView.phi = π/2 - 0.2
        freeView.theta = 0
        freeView.scrolls = true

        views = [freeView]

        // Kites

        add(KiteController.kite0, color: .purple)
        add(KiteController.kite1, color: .orange)

        // The dome

        KiteController.shared.settings.tetherLength.asObservable()
            .bind { radius in self.views.forEach { $0.domeRadius = radius } }
            .disposed(by: bag)

        // Coordinate axes

        [(e_x, NSColor.red), (e_y, .green), (e_z, .blue)].map { ArrowDrawable(vector: 10*$0, color: $1) }.forEach(add)

        // C and the path

        let tetherLength = KiteController.shared.settings.tetherLength.asObservable()
        let turningRadius = KiteController.shared.settings.turningRadius.asObservable()
        let d = Observable.combineLatest(tetherLength, turningRadius, resultSelector: getD)

        let phiC = KiteController.shared.settings.phiC.asObservable()
        let thetaC = KiteController.shared.settings.thetaC.asObservable()
        let cPoint = Observable.combineLatest(phiC, thetaC, d, resultSelector: getC)

        add(cDrawable)

        cPoint
            .bind { pos in self.cDrawable.position = pos}
            .disposed(by: bag)

        add(piCircleDrawable)

        cPoint
            .bind { pos in self.piCircleDrawable.position = pos; self.piCircleDrawable.normal = pos.unit }
            .disposed(by: bag)

        KiteController.shared.settings.turningRadius.asObservable()
            .bind { radius in self.piCircleDrawable.radius = radius }
            .disposed(by: bag)

        // Trace views as controls

        let requestedPositions = [KiteController.kite0.positionTarget, KiteController.kite1.positionTarget]
        views.forEach { $0.requestedPositions = requestedPositions }

        // Redrawing

        requestedPositions.map { $0.asObservable() }.forEach(useAsRedrawTrigger)
        useAsRedrawTrigger(cPoint)
        redrawViews()

        // Log reading

        add(pathLogDrawable)
        add(circleLogDrawable)
        add(targetLogDrawable)
        add(arcLogDrawable)
        add(arcCenterLogDrawable)
        add(arc2LogDrawable)
        add(arcCenter2LogDrawable)

        add(velocityLogDrawable)

        steppedLogDrawables.forEach(add)

        LogProcessor.shared.change.bind(onNext: updateLog).disposed(by: bag)

        loadButton.rx.tap.bind(onNext: openVideoFile).addDisposableTo(bag)

        videoOffset.rx.value.bind { _  in self.scrubVideo() }.addDisposableTo(bag)

        updateLog(.reset)
    }

    private func openVideoFile() {
        let panel = NSOpenPanel()
        panel.begin { result in
            if result == NSFileHandlingPanelOKButton {
                self.videoView.player = AVPlayer(url: panel.urls[0])
            }
        }
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

    private func scrubVideo() {
        let seekTime = CMTime(seconds: LogProcessor.shared.timeSinceStart + videoOffset.doubleValue, preferredTimescale: 1000000)
        videoView.player?.seek(to: seekTime)
    }

    private func updateLog(_ change: LogProcessor.Change) {
        logLabel.stringValue = LogProcessor.shared.logText

        let isEmpty = LogProcessor.shared.model.isEmpty

        circleLogDrawable.isHidden = isEmpty
        pathLogDrawable.isHidden = isEmpty
        steppedLogDrawables.forEach { $0.isHidden = isEmpty }

        piCircleDrawable.isHidden = !isEmpty
        cDrawable.isHidden = !isEmpty

        if change == .reset {
            views.forEach { $0.domeRadius = Scalar(LogProcessor.shared.model.tetherLength) }
        }
        else if change == .scrubbed {
            scrubVideo()
        }

        if isEmpty {
            return
        }

        for (index, current) in LogProcessor.shared.steppedConfigurations.enumerated() {
            if index >= steppedLogDrawables.count {
                let newDrawable = KiteDrawable(color: NSColor(red: 1, green: 0, blue: 0, alpha: 0.3))
                add(newDrawable)
                steppedLogDrawables.append(newDrawable)
            }

            steppedLogDrawables[index].position = current.loc.pos
            steppedLogDrawables[index].orientation = current.ori.orientation
            steppedLogDrawables[index].isHidden = false
        }

        let drawablesNeeded = LogProcessor.shared.steppedConfigurations.count
        for kiteDrawable in steppedLogDrawables[drawablesNeeded..<steppedLogDrawables.count] {
            kiteDrawable.isHidden = true
        }

        if let currentLocation = LogProcessor.shared.steppedConfigurations.first?.loc {
            velocityLogDrawable.position = currentLocation.pos
            velocityLogDrawable.vector = currentLocation.vel
        }

        if let arc = LogProcessor.shared.arcData, arc.c.norm > 0 {
            circleLogDrawable.position = arc.c
            circleLogDrawable.normal = arc.c.unit
            circleLogDrawable.radius = CGFloat(LogProcessor.shared.model.turningRadius)

            targetLogDrawable.position = arc.target

            arcCenterLogDrawable.position = arc.center

            arcLogDrawable.position = arc.center
            arcLogDrawable.normal = arc.c.unit
            arcLogDrawable.radius = arc.radius

//            let radialVector = start - arc.center
//            let normal = radialVector×tangent
//
//            arcLogDrawable.plane = Plane(center: center, normal: normal)
//            arcLogDrawable.radius = radialVector.norm
//            arcLogDrawable.startAngle = start.collapsed(on: plane.bases).phi


//            arcCenter2LogDrawable.position = arc.center2
//
//            arc2LogDrawable.position = arc.center2
//            arc2LogDrawable.normal = arc.c.unit
//            arc2LogDrawable.radius = arc.radius2
        }

        if change == .changedRange {
            pathLogDrawable.update(LogProcessor.shared.pathLocations.map(TimedLocation.getPosition))
        }

        redrawViews()
    }
}

func getD(tether: Scalar, r: Scalar) -> Scalar {
    return sqrt(tether*tether - r*r)
}

func getC(phi: Scalar, theta: Scalar, d: Scalar) -> Vector {
    return Vector(phi: phi, theta: π/2 + theta, r: d)
}

extension AffineTransform {
    init(translationBy point: CGPoint) {
        self = AffineTransform(translationByX: point.x, byY: point.y)
    }
}
