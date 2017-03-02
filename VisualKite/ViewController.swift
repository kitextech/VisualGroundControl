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

//        let animation = CABasicAnimation(keyPath: "rotation")
//        animation.toValue = NSValue(scnVector4: SCNVector4(x: CGFloat(0), y: CGFloat(1), z: CGFloat(0), w: CGFloat(M_PI)*2))
//        animation.duration = 3
//        ship.addAnimation(animation, forKey: nil)

final class GameViewController: NSViewController, SCNSceneRendererDelegate {
    @IBOutlet weak var sceneView: SCNView!
    @IBOutlet weak var vSlider: NSSlider!
    @IBOutlet weak var hSlider: NSSlider!
    @IBOutlet weak var phaseSlider: NSSlider!
    @IBOutlet weak var windSlider: NSSlider!
    
    private let bag = DisposeBag()
    private let kite = KiteEmulator()
    private let viewer = KiteViewer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewer.setup(with: sceneView)
        sceneView.delegate = self
        sceneView.play(nil)
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
        
//        Observable.combineLatest(windSlider.rx.value, vSlider.rx.value, hSlider.rx.value, resultSelector: Vector.init)
//            .bindTo(viewer.attitude).disposed(by: bag)
        
//        Observable.combineLatest(vSlider.rx.value, hSlider.rx.value, windSlider.rx.value, resultSelector: noOp)
//            .map { Matrix(rotation: .ex, by: Scalar($0.0))*Matrix(rotation: .ey, by: Scalar($0.1))*Matrix(rotation: .ez, by: Scalar($0.2)) }
//            .subscribe(onNext: { self.viewer.ship.pivot = $0 })
//            .disposed(by: bag)
        
        kite.position.bindTo(viewer.position).disposed(by: bag)
        kite.velocity.bindTo(viewer.velocity).disposed(by: bag)
        kite.attitude.bindTo(viewer.attitude).disposed(by: bag)
        kite.wind.bindTo(viewer.wind).disposed(by: bag)

        kite.tetherPoint.bindTo(viewer.tetherPoint).disposed(by: bag)
        kite.turningPoint.bindTo(viewer.turningPoint).disposed(by: bag)
    }
    
    // MARK: - Helper Methods
}

let π = Scalar(M_PI)
