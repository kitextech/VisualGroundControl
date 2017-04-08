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

    @IBOutlet weak var errorLabel: NSTextField!

    @IBOutlet weak var positionLabel: NSTextField!
    @IBOutlet weak var tetherLengthSlider: NSSlider!
    @IBOutlet weak var tetherLengthLabel: NSTextField!

    @IBOutlet weak var deltaBxStepper: NSStepper!
    @IBOutlet weak var deltaByStepper: NSStepper!
    @IBOutlet weak var deltaBzStepper: NSStepper!

    @IBOutlet weak var phiCSlider: NSSlider!
    @IBOutlet weak var thetaCSlider: NSSlider!
    @IBOutlet weak var turningRadiousSlider: NSSlider!

    @IBOutlet weak var phiCLabel: NSTextField!
    @IBOutlet weak var thetaCLabel: NSTextField!
    @IBOutlet weak var turningRLabel: NSTextField!

    @IBOutlet weak var tetheredHoverThrustSlider: NSSlider!

    // MARK: Private

    private let kitePosition = Variable<Vector>(.zero)

    private let tweakedB = Variable<Vector>(.zero)

    // MARK: BAG
    private let bag = DisposeBag()
    
    @IBAction func pressedUseAsB(_ sender: NSButton) {
        kite.positionB.value = tweakedB.value
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        kite.location.map(KiteLocation.getPosition).bindTo(kitePosition).disposed(by: bag)

        tetherLengthSlider.scalar.bindTo(kite.tetherLength).disposed(by: bag)
        
        kite.tetherLength.asObservable().map(getScalarString).bindTo(tetherLengthLabel.rx.text).disposed(by: bag)

 //       let db = Observable.combineLatest(deltaBxStepper.scalar, deltaByStepper.scalar, deltaBzStepper.scalar, resultSelector: Vector.fromScalars)

   //     Observable.combineLatest(kitePosition.asObservable(), db, resultSelector: +).bindTo(tweakedB).disposed(by: bag)

        kitePosition.asObservable().bindTo(tweakedB).disposed(by: bag)

        tweakedB.asObservable().map(getVectorString).bindTo(positionLabel.rx.text).disposed(by: bag)

        tetheredHoverThrustSlider.scalar.bindTo(kite.tetheredHoverThrust).disposed(by: bag)

        kite.errorMessage.bindTo(errorLabel.rx.text).disposed(by: bag)

//        phiCSlider.scalar.map(getScalarString).bindTo(phiCLabel.rx.text).disposed(by: bag)
//        thetaCSlider.scalar.map(getScalarString).bindTo(thetaCLabel.rx.text).disposed(by: bag)
//        turningRadiousSlider.scalar.map(getScalarString).bindTo(turningRLabel.rx.text).disposed(by: bag)

        phiCSlider.scalar.bindTo(kite.phiC).disposed(by: bag)
        thetaCSlider.scalar.bindTo(kite.thetaC).disposed(by: bag)
        turningRadiousSlider.scalar.bindTo(kite.turningRadius).disposed(by: bag)
    }

    @IBAction func selectedOffboardMode(_ sender: NSButton) {
        let submode = OffboardFlightMode(sender.tag, subNumber: 0)
        kite.flightMode.value = .offboard(subMode: submode)
    }

    @IBAction func togglePosCtr(_ sender: NSButton) {
        kite.offboardPositionTethered.value = !kite.offboardPositionTethered.value
    }

    private func getScalarString(scalar: Scalar) -> String {
        return String(format: "%.2f", scalar)
    }

    private func getVectorString(vector: Vector) -> String {
        return String(format: "(%.2f, %.2f, %.2f", vector.x, vector.y, vector.z)
    }
}

