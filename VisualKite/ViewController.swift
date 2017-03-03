//
//  GameViewController.swift
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

let π = Scalar(M_PI)

public let e_x = Vector.ex
public let e_y = Vector.ey
public let e_z = Vector.ez

protocol KiteType {
    func update(time: TimeInterval)
    var position: PublishSubject<Vector> { get }
    var attitude: PublishSubject<Vector> { get }
}

protocol AnalyserType {
    var estimatedWind: PublishSubject<Vector?> { get }
    var tetherPoint: PublishSubject<Vector?> { get }
    var turningPoint: PublishSubject<Vector?> { get }
    var turningRadius: PublishSubject<Scalar?> { get }
    var isTethered: PublishSubject<Scalar> { get }
}

final class GameViewController: NSViewController, SCNSceneRendererDelegate {
    @IBOutlet weak var sceneView: SCNView!
    @IBOutlet weak var vSlider: NSSlider!
    @IBOutlet weak var hSlider: NSSlider!
    @IBOutlet weak var phaseSlider: NSSlider!
    @IBOutlet weak var windSlider: NSSlider!
    
    @IBOutlet weak var slider0: NSSlider!
    @IBOutlet weak var slider1: NSSlider!
    @IBOutlet weak var slider2: NSSlider!
    
    private let bag = DisposeBag()
    private let kite = KiteEmulator()
    private let viewer = KiteViewer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewer.setup(with: sceneView)
        sceneView.delegate = self
        sceneView.play(nil)
    }
    
    @IBAction func pause(_ sender: Any) {
        if sceneView.isPlaying {
            sceneView.pause(sender)
            kite.paused = true
        }
        else {
            sceneView.play(sender)
            kite.paused = false
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        kite.update(time: time)
    }

    override func awakeFromNib(){
        super.awakeFromNib()
        
        phaseSlider.minValue = Double(0)
        phaseSlider.maxValue = Double(2*π)

        vSlider.minValue = Double(0)
        vSlider.maxValue = Double(π/2)
        
        hSlider.minValue = Double(-π)
        hSlider.maxValue = Double(π)

        windSlider.minValue = Double(-π)
        windSlider.maxValue = Double(π)
                
        phaseSlider.rx.value
            .map(Scalar.init(_:))
            .bindTo(kite.phaseSpeed)
            .disposed(by: bag)

//        phaseSlider.rx.value
//            .map(Scalar.init(_:))
//            .bindTo(kite.forcedPhase)
//            .disposed(by: bag)

        vSlider.rx.value
            .map(Scalar.init(_:))
            .bindTo(kite.gamma)
            .disposed(by: bag)

        hSlider.rx.value
            .map(Scalar.init(_:))
            .bindTo(kite.phi)
            .disposed(by: bag)

        windSlider.rx.value
            .map(Scalar.init(_:))
            .bindTo(kite.phiWind)
            .disposed(by: bag)

        // ----

        slider0.minValue = Double(-π)
        slider0.maxValue = Double(+π)

        slider1.minValue = Double(-π)
        slider1.maxValue = Double(+π)

        slider2.minValue = Double(-π)
        slider2.maxValue = Double(+π)

        Observable.combineLatest(slider0.rx.value.asObservable(), slider1.rx.value.asObservable(), slider2.rx.value.asObservable(), resultSelector: Vector.init).bindTo(viewer.attitude).disposed(by: bag)
        
        // ----
        
        kite.position.bindTo(viewer.position).disposed(by: bag)
        kite.velocity.bindTo(viewer.velocity).disposed(by: bag)
//        kite.attitude.bindTo(viewer.attitude).disposed(by: bag)
        kite.wind.bindTo(viewer.wind).disposed(by: bag)

        kite.tetherPoint.bindTo(viewer.tetherPoint).disposed(by: bag)
        kite.turningPoint.bindTo(viewer.turningPoint).disposed(by: bag)
    }
    
}


//        let animation = CABasicAnimation(keyPath: "rotation")
//        animation.toValue = NSValue(scnVector4: SCNVector4(x: CGFloat(0), y: CGFloat(1), z: CGFloat(0), w: CGFloat(M_PI)*2))
//        animation.duration = 3
//        ship.addAnimation(animation, forKey: nil)

//        Observable.combineLatest(windSlider.rx.value, vSlider.rx.value, hSlider.rx.value, resultSelector: Vector.init)
//            .bindTo(viewer.attitude).disposed(by: bag)

//        Observable.combineLatest(vSlider.rx.value, hSlider.rx.value, windSlider.rx.value, resultSelector: noOp)
//            .map { Matrix(rotation: .ex, by: Scalar($0.0))*Matrix(rotation: .ey, by: Scalar($0.1))*Matrix(rotation: .ez, by: Scalar($0.2)) }
//            .subscribe(onNext: { self.viewer.ship.pivot = $0 })
//            .disposed(by: bag)
