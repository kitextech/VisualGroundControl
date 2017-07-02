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
    public let globalB: Variable<GPSVector> = Variable(.zero)

    public let tetherLength: Variable<Scalar> = Variable(100)
    public let phiC: Variable<Scalar> = Variable(0)
    public let thetaC: Variable<Scalar> = Variable(0)
    public let turningRadius: Variable<Scalar> = Variable(10)
    public let tetheredHoverThrust: Variable<Scalar> = Variable(0)

    // MARK: BAG
    private let bag = DisposeBag()

    func setup(_ tetherLength: Observable<Scalar>, _ phiC: Observable<Scalar>, _ thetaC: Observable<Scalar>, _ turningRadius: Observable<Scalar>, _ tetheredHoverThrust: Observable<Scalar>) {

        tetherLength.bind(to: self.tetherLength).disposed(by: bag)
        phiC.bind(to: self.phiC).disposed(by: bag)
        thetaC.bind(to: self.thetaC).disposed(by: bag)
        turningRadius.bind(to: self.turningRadius).disposed(by: bag)
        tetheredHoverThrust.bind(to: self.tetheredHoverThrust).disposed(by: bag)
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

    @IBOutlet weak var bLabel: NSTextField!
    
    @IBOutlet weak var position0Label: NSTextField!
    @IBOutlet weak var position1Label: NSTextField!

    @IBOutlet weak var ned0Label: NSTextField!
    @IBOutlet weak var ned1Label: NSTextField!

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
        KiteController.shared.settings.globalB.value = KiteController.kite0.latestGlobalPosition
    }

    @IBAction func pressedUse1AsB(_ sender: NSButton) {
        KiteController.shared.settings.globalB.value = KiteController.kite1.latestGlobalPosition
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        func prepend(_ string: String) -> (String) -> String { return { string + ": " + $0 } }

        let tetherLength = tetherLengthSlider.scalar.shareReplayLatestWhileConnected()
        let phiC = phiCSlider.scalar.shareReplayLatestWhileConnected()
        let thetaC = thetaCSlider.scalar.shareReplayLatestWhileConnected()
        let turningRadius = turningRadiusSlider.scalar.shareReplayLatestWhileConnected()
        let tetheredHoverThrust = tetheredHoverThrustSlider.scalar.shareReplayLatestWhileConnected()

        KiteController.shared.settings.setup(tetherLength, phiC, thetaC, turningRadius, tetheredHoverThrust)

        // Parameters
        let gpsString = { (p: GPSVector) in "GPS: \(p.lat), \(p.lon). \(p.alt/1000)" }

        KiteController.shared.settings.globalB.asObservable().map(gpsString).map(prepend("B ")).bind(to: bLabel.rx.text).disposed(by: bag)

        tetherLength.map(getScalarString).bind(to: tetherLengthLabel.rx.text).disposed(by: bag)
        phiC.map(getScalarString).bind(to: phiCLabel.rx.text).disposed(by: bag)
        thetaC.map(getScalarString).bind(to: thetaCLabel.rx.text).disposed(by: bag)
        turningRadius.map(getScalarString).bind(to: turningRLabel.rx.text).disposed(by: bag)
        tetheredHoverThrust.map(getScalarString).bind(to: tetheredHoverThrustLabel.rx.text).disposed(by: bag)

        // Positions
        let stripTime = { (p: TimedGPSVector) in p.pos }
        KiteController.kite0.globalPosition.asObservable().map(stripTime).map(gpsString).bind(to: position0Label.rx.text).disposed(by: bag)
        KiteController.kite1.globalPosition.asObservable().map(stripTime).map(gpsString).bind(to: position1Label.rx.text).disposed(by: bag)

        let nedString = { (p: TimedLocation) in "NED: \(p.pos.x), \(p.pos.y). \(p.pos.z)" }
        KiteController.kite0.location.map(nedString).bind(to: ned0Label.rx.text).disposed(by: bag)
        KiteController.kite1.location.map(nedString).bind(to: ned1Label.rx.text).disposed(by: bag)

        // Errors
        let kite0Errors = KiteController.kite0.errorMessage.map(prepend("kite0"))
        let kite1Errors = KiteController.kite1.errorMessage.map(prepend("kite1"))

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

