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
    var position: PublishSubject<Vector> { get }
    var attitude: PublishSubject<Vector> { get }
}

protocol AnalyserType {
    var tetherPoint: PublishSubject<Vector?> { get }
    var turningPoint: PublishSubject<Vector?> { get }
    var turningRadius: PublishSubject<Scalar?> { get }
    var isTethered: PublishSubject<Scalar> { get }
}

//        let animation = CABasicAnimation(keyPath: "rotation")
//        animation.toValue = NSValue(scnVector4: SCNVector4(x: CGFloat(0), y: CGFloat(1), z: CGFloat(0), w: CGFloat(M_PI)*2))
//        animation.duration = 3
//        ship.addAnimation(animation, forKey: nil)

final class GameViewController: NSViewController {
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
    }
    
    override func awakeFromNib(){
        super.awakeFromNib()
        
        vSlider.minValue = Double(0)
        vSlider.maxValue = Double(π/2)
        
        hSlider.minValue = Double(-π)
        hSlider.maxValue = Double(π)
        
        phaseSlider.minValue = Double(0)
        phaseSlider.maxValue = Double(2*π)

        windSlider.minValue = Double(-π)
        windSlider.maxValue = Double(π)
        
        vSlider.rx.value
            .map(Scalar.init(_:))
            .bindTo(kite.gamma)
            .disposed(by: bag)

        hSlider.rx.value
            .map(Scalar.init(_:))
            .bindTo(kite.phi)
            .disposed(by: bag)

        phaseSlider.rx.value
            .map(Scalar.init(_:))
            .bindTo(kite.phase)
            .disposed(by: bag)

        let wind = windSlider.rx.value.map(Scalar.init(_:))

        wind.bindTo(kite.phiWind)
            .disposed(by: bag)

        // ----
        
        kite.position.bindTo(viewer.position).disposed(by: bag)
        kite.attitude.bindTo(viewer.attitude).disposed(by: bag)
        kite.tetherPoint.bindTo(viewer.tetherPoint).disposed(by: bag)
        kite.turningPoint.bindTo(viewer.turningPoint).disposed(by: bag)
        
        wind.bindTo(kite.phiWind).disposed(by: bag)
        
        
        let g = Observable.combineLatest(kite.position, kite.attitude, resultSelector: { $0 })
    }
    
    // MARK: - Helper Methods
}

let π = Scalar(M_PI)
