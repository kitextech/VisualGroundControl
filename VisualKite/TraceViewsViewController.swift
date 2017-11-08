//
//  TraceViewsViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-18.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//
//        ×

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

    @IBOutlet weak var toggleViewButton: NSButton!
    @IBOutlet weak var restartButton: NSButton!
    @IBOutlet weak var togglePlayButton: NSButton!

    // MARK: - Private

    private let bag = DisposeBag()
    private var views: [TraceView] = []

    private let cDrawable = BallDrawable(color: .red)
    private let piCircleDrawable = CircleDrawable()

    private let velocityLogDrawable = ArrowDrawable(color: .darkGray, hideBall: true)
    private let targetLogDrawable = BallDrawable(color: .red)

    private let arcLogDrawable = ArcDrawable(color: .orange)
    private let arcCenterLogDrawable = BallDrawable(color: .orange)

    private let arc2LogDrawable = CircleDrawable(color: .purple)
    private let arcCenter2LogDrawable = BallDrawable(color: .purple)

    private let circleLogDrawable = CircleDrawable()
    private let pathLogDrawable = PathDrawable()
    private var steppedLogDrawables = [KiteDrawable(color: .red)]

    private var isPlayingVideo: Bool { return videoView.player?.isPlaying ?? false }
    private var isLoadedVideo: Bool { return videoView.player != nil }
    private var shouldShowVideo = true

    private var videoTimeObserver: Any?

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
//        add(arc2LogDrawable)
//        add(arcCenter2LogDrawable)

        add(velocityLogDrawable)

        steppedLogDrawables.forEach(add)

        LogProcessor.shared.change.bind(onNext: updateLog).disposed(by: bag)

        toggleViewButton.rx.tap.bind(onNext: tappedToggleViewButton).addDisposableTo(bag)
        togglePlayButton.rx.tap.bind(onNext: tappedTogglePlayButton).addDisposableTo(bag)
        restartButton.rx.tap.bind(onNext: tappedRestartButton).addDisposableTo(bag)

        updateLog(.reset)
        updateUI()
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

    private func tappedRestartButton() {
        videoView.player?.seek(to: CMTime(seconds: 0, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
    }

    private func tappedTogglePlayButton() {
        if isPlayingVideo {
            videoView.player?.pause()
        }
        else {
            videoView.player?.play()
        }

        updateUI()
    }

    private func tappedToggleViewButton() {
        shouldShowVideo = !shouldShowVideo
        updateUI()
        updatePlayer()
    }

    private func loadVideoFile(logUrl: URL) {
        let filename = logUrl.lastPathComponent
            .replacingOccurrences(of: "_replayed", with: "")
            .replacingOccurrences(of: ".ulg", with: ".mov")
        let url = logUrl.deletingLastPathComponent().appendingPathComponent(filename)

        print("-----")
        print("-----")
        print("-----")
        print("-----")
        print("LOADING FILE: \(filename)")
        print("LOADING URL: \(url)")

        videoView.player = AVPlayer(url: url)

        print("PLAYER: \(videoView.player == nil ? "nil" : "exist")")

        if let player = videoView.player {
            print("PLAYER ERROR: \(player.error?.localizedDescription ?? "---")")
            print("PLAYER PLAYING: \(player.isPlaying)")
            print("PLAYER REASON: \(player.reasonForWaitingToPlay ?? "--")")
            print("PLAYER STATUS: \(player.status)")
        }

        updatePlayer()
        updateUI()
    }

    private func updatePlayer() {
        guard let player = videoView.player else {
            return
        }

        if shouldShowVideo {
            let interval = CMTime(seconds: 0.05, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            videoTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { cmTime in
                let t = TimeInterval(CMTimeGetSeconds(cmTime))
                LogProcessor.shared.requestedTime = .video(t: t)
            }
        }
        else if let videoTimeObserver = videoTimeObserver {
            videoView.player?.removeTimeObserver(videoTimeObserver)
        }
    }

    private func updateUI() {
        toggleViewButton.title = shouldShowVideo ? "Hide video" : "Show video"
        togglePlayButton.title = isPlayingVideo ? "Pause" : "Play"

        toggleViewButton.isEnabled = isLoadedVideo
        restartButton.isEnabled = isLoadedVideo
        togglePlayButton.isEnabled = isLoadedVideo

        videoView.isHidden = !shouldShowVideo || !isLoadedVideo
    }

    private func updateLog(_ change: LogProcessor.Change) {
        logLabel.stringValue = LogProcessor.shared.logText

        let isEmpty = LogProcessor.shared.model?.isEmpty ?? true

        circleLogDrawable.isHidden = isEmpty
        arcLogDrawable.isHidden = isEmpty
        pathLogDrawable.isHidden = isEmpty
        steppedLogDrawables.forEach { $0.isHidden = isEmpty }

        piCircleDrawable.isHidden = !isEmpty
        cDrawable.isHidden = !isEmpty

        guard let model = LogProcessor.shared.model, !model.isEmpty else {
            videoView.player = nil
            return
        }

        switch change {
        case .scrubbed:
            scrubbedLog()
        case .scrubbedByVideo:
            break
        case .changedRange:
            pathLogDrawable.update(LogProcessor.shared.pathLocations.map(TimedLocation.getPosition))
        case .reset:
            let radius: Scalar
            if let model = LogProcessor.shared.model {
                if !isLoadedVideo {
                    loadVideoFile(logUrl: model.url)
                }
                else {
                    videoView.player = nil
                }

                updateUI()
                radius = Scalar(model.tetherLength)
            }
            else {
                radius = KiteController.shared.settings.tetherLength.value
            }
            views.forEach { $0.domeRadius = radius }
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

            if let arc = LogProcessor.shared.arcData, arc.c.norm > 0 {
                circleLogDrawable.position = arc.c
                circleLogDrawable.normal = arc.c.unit
                circleLogDrawable.radius = CGFloat(model.turningRadius)

                targetLogDrawable.position = arc.target

                arcCenterLogDrawable.position = arc.center

                let plane = Plane(center: arc.center, normal: arc.c.unit)
                arcLogDrawable.plane = plane
                arcLogDrawable.radius = arc.radius
                arcLogDrawable.startAngle = plane.collapse(vector: currentLocation.pos).phi

                let collapsedLoc = (currentLocation.pos - arc.center).collapsed(on: plane.bases)
                let collapsedTarget = (arc.target - arc.center).collapsed(on: plane.bases)
                let collapsedAngle = collapsedLoc.signedAngle(to: collapsedTarget)

                arcLogDrawable.angle = (arc.radius*collapsedAngle < 0 ? 2*π : 0) + (arc.radius < 0 ? -1 : 1)*collapsedAngle
            }
        }

        redrawViews()
    }

    private func scrubbedLog() {
        let seekTime = CMTime(seconds: LogProcessor.shared.videoTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
//        print("Scrub to: \(LogProcessor.shared.videoTime) - \(seekTime)")
        videoView.player?.seek(to: seekTime)
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

extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }
}
