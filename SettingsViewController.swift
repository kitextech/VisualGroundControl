//
//  SettingsViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-15.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import RxSwift

class SettingsModel {
    private let localPositions: [Variable<Vector>] = [Variable(.zero), Variable(.zero)]
    private var currentLocalPositions: [Vector] = [.zero, .zero]
    private var currentGlobalPositions: [GPSVector] = [.zero, .zero]

    public let tetherLength: Observable<Scalar>
    public let phiC: Observable<Scalar>
    public let thetaC: Observable<Scalar>
    public let turningRadius: Observable<Scalar>
    public let tetheredHoverThrust: Observable<Scalar>

    private let bag = DisposeBag()

    init(_ tetherLength: Observable<Scalar>, _ tetheredHoverThrust: Observable<Scalar>, _ phiC: Observable<Scalar>, _ thetaC: Observable<Scalar>, _ turningRadius: Observable<Scalar>) {

        self.tetherLength = tetherLength
        self.tetheredHoverThrust = tetheredHoverThrust
        self.phiC = phiC
        self.thetaC = thetaC
        self.turningRadius = turningRadius

        self.turningRadius.bind(onNext: { Swift.print("Settings: Turning radius changed: \($0)") }).disposed(by: bag)
    }
}

class SettingsViewController: NSViewController {
    private var model: SettingsModel!

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
        KiteController.shared.saveB(kite: 0)
    }

    @IBAction func pressedUse1AsB(_ sender: NSButton) {
        KiteController.shared.saveB(kite: 1)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

//        model = SettingsModel(tetherLengthSlider.scalar, tetheredHoverThrustSlider.scalar, phiCSlider.scalar, thetaCSlider.scalar, turningRadiusSlider.scalar)

//        KiteController.shared.setModel(model)

        // Parameters
        tetherLengthSlider.scalar.map(getScalarString).bind(to: tetherLengthLabel.rx.text).disposed(by: bag)

        let positionString = { (p: TimedGPSVector) in "GPS: \(p.pos.lat), \(p.pos.lon). \(p.pos.alt/1000)" }

        phiCSlider.scalar.map(getScalarString).bind(to: phiCLabel.rx.text).disposed(by: bag)
        thetaCSlider.scalar.map(getScalarString).bind(to: thetaCLabel.rx.text).disposed(by: bag)
//        turningRadiusSlider.scalar.map(getScalarString).bind(to: turningRLabel.rx.text).disposed(by: bag)

        func printme1(scalar: Scalar) {
            Swift.print("1: \(scalar)")
        }

        func printme2(scalar: Scalar) {
            Swift.print("2: \(scalar)")
        }

        func printme3(scalar: Scalar) {
            Swift.print("3: \(scalar)")
        }

        turningRadiusSlider.scalar.share(scope: .forever).subscribe(onNext: printme1).disposed(by: bag)
        turningRadiusSlider.scalar.share(scope: .forever).subscribe(onNext: printme2).disposed(by: bag)

        tetheredHoverThrustSlider.scalar.map(getScalarString).bind(to: tetheredHoverThrustLabel.rx.text).disposed(by: bag)

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

