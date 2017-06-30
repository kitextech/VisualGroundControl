//
//  SettingsViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-15.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import RxSwift

struct SettingsModel {
    public let tetherLength: Variable<Scalar> = Variable(0)
    public let phiC: Variable<Scalar> = Variable(0)
    public let thetaC: Variable<Scalar> = Variable(0)
    public let turningRadius: Variable<Scalar> = Variable(0)
    public let tetheredHoverThrust: Variable<Scalar> = Variable(0)

    // MARK: BAG
    private let bag = DisposeBag()

    init(_ tetherLength: Observable<Scalar>, _ tetheredHoverThrust: Observable<Scalar>, _ phiC: Observable<Scalar>, _ thetaC: Observable<Scalar>, _ turningRadius: Observable<Scalar>) {

        tetherLength.bind(to: self.tetherLength).disposed(by: bag)
        tetheredHoverThrust.bind(to: self.tetheredHoverThrust).disposed(by: bag)
        phiC.bind(to: self.phiC).disposed(by: bag)
        thetaC.bind(to: self.thetaC).disposed(by: bag)
        turningRadius.bind(to: self.turningRadius).disposed(by: bag)
    }
}

class SettingsViewController: NSViewController {
    // MARK: - Outlets

    @IBOutlet weak var tetherLengthSlider: NSSlider!

    @IBOutlet weak var phiCSlider: NSSlider!
    @IBOutlet weak var thetaCSlider: NSSlider!
    @IBOutlet weak var turningRadiusSlider: NSSlider!

    @IBOutlet weak var tetheredHoverThrustSlider: NSSlider!

    // Labels

    @IBOutlet weak var position0Label: NSTextField!
    @IBOutlet weak var position1Label: NSTextField!
    @IBOutlet weak var errorLabel: NSTextField!

    @IBOutlet weak var tetherLengthLabel: NSTextField!

    @IBOutlet weak var phiCLabel: NSTextField!
    @IBOutlet weak var thetaCLabel: NSTextField!
    @IBOutlet weak var turningRLabel: NSTextField!

    @IBOutlet weak var tetheredHoverThrustLabel: NSTextField!

    // MARK: Private

    // MARK: BAG
    private let bag = DisposeBag()
    
    @IBAction func pressedUse0AsB(_ sender: NSButton) {
        KiteController.shared.saveB(from: 0)
    }

    @IBAction func pressedUse1AsB(_ sender: NSButton) {
        KiteController.shared.saveB(from: 1)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let tetherLength = tetherLengthSlider.scalar.shareReplayLatestWhileConnected()
        let tetheredHoverThrust = tetheredHoverThrustSlider.scalar.shareReplayLatestWhileConnected()
        let phiC = phiCSlider.scalar.shareReplayLatestWhileConnected()
        let thetaC = thetaCSlider.scalar.shareReplayLatestWhileConnected()
        let turningRadius = turningRadiusSlider.scalar.shareReplayLatestWhileConnected()

        let settings = SettingsModel(tetherLength, tetheredHoverThrust, phiC, thetaC, turningRadius)

        KiteController.shared.setModel(settings: settings)

        // Parameters

        let positionString = { (p: TimedGPSVector) in "GPS: \(p.pos.lat), \(p.pos.lon). \(p.pos.alt/1000)" }

        tetherLength.map(getScalarString).bind(to: tetherLengthLabel.rx.text).disposed(by: bag)
        phiC.map(getScalarString).bind(to: phiCLabel.rx.text).disposed(by: bag)
        thetaC.map(getScalarString).bind(to: thetaCLabel.rx.text).disposed(by: bag)
        turningRadius.map(getScalarString).bind(to: turningRLabel.rx.text).disposed(by: bag)
        tetheredHoverThrust.map(getScalarString).bind(to: tetheredHoverThrustLabel.rx.text).disposed(by: bag)

        // Positions
        KiteController.shared.kite0.globalPosition.asObservable().map(positionString).bind(to: position0Label.rx.text).disposed(by: bag)
        KiteController.shared.kite1.globalPosition.asObservable().map(positionString).bind(to: position1Label.rx.text).disposed(by: bag)

        // Errors
        func prepend(_ string: String) -> (String) -> String { return { string + ": " + $0 } }

        let kite0Errors = KiteController.shared.kite0.errorMessage.map(prepend("kite0"))
        let kite1Errors = KiteController.shared.kite1.errorMessage.map(prepend("kite1"))

        Observable.merge(kite0Errors, kite1Errors).bind(to: errorLabel.rx.text).disposed(by: bag)
    }

    @IBAction func selectedOffboardMode(_ sender: NSButton) {
//        let submode = OffboardFlightMode(sender.tag, subNumber: 0)
//        model.kite.flightMode.value = .offboard(subMode: submode)
    }

    @IBAction func togglePosCtr(_ sender: NSButton) {
//        model.kite.offboardPositionTethered.value = !model.kite.offboardPositionTethered.value
    }

    private func getScalarString(scalar: Scalar) -> String {
        return String(format: "%.2f", scalar)
    }
}

