//
//  SettingsViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-15.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import RxSwift

class SettingsViewController: NSViewController {
    private let kite = KiteLink.shared
    
    // MARK: - Outlets
    @IBOutlet weak var positionLabel: NSTextField!
    @IBOutlet weak var tetherLengthSlider: NSSlider!
    @IBOutlet weak var tetherLengthLabel: NSTextField!

    @IBOutlet weak var deltaBxSlider: NSSlider!
    @IBOutlet weak var deltaBySlider: NSSlider!
    @IBOutlet weak var deltaBzSlider: NSSlider!

    // MARK: Private

    private let kitePosition = Variable<Vector>(.zero)

    // MARK: BAG
    private let bag = DisposeBag()
    
    @IBAction func pressedUseAsB(_ sender: NSButton) {
        kite.positionB.value = kitePosition.value + Vector(deltaBxSlider.doubleValue, deltaBySlider.doubleValue, deltaBzSlider.doubleValue)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        kite.location.map(KiteLocation.getPosition).bindTo(kitePosition).disposed(by: bag)

        kitePosition.asObservable().map(getVectorString).bindTo(positionLabel.rx.text).disposed(by: bag)

        tetherLengthSlider.scalar.bindTo(kite.tetherLength).disposed(by: bag)
        //        tetherLengthSlider.scalar.map(getString).bindTo(tetherLengthLabel.rx.text).disposed(by: bag)
    }

    @IBAction func selectedOffboardMode(_ sender: NSButton) {
        let submode = OffboardFlightMode(sender.tag, subNumber: 0)
        kite.flightMode.value = .offboard(subMode: submode)
    }

    private func getScalarString(scalar: Scalar) -> String {
        return String(format: "%.2f", scalar)
    }

    private func getVectorString(vector: Vector) -> String {
        return String(format: "(%.2f, %.2f, %.2f", vector.x, vector.y, vector.z)
    }
}

struct Settings {
    public static let shared = Settings()
        
}
